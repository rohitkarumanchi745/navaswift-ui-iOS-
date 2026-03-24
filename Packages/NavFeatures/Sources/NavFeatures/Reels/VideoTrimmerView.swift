import SwiftUI
import AVFoundation
import NavCore
import NavServices

// MARK: - ViewModel

@MainActor
final class VideoTrimmerViewModel: ObservableObject {
    let asset: AVURLAsset
    let maxDuration: Double = 30.0

    @Published var frameThumbnails: [UIImage] = []
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 30
    @Published var currentPlaybackTime: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var videoDuration: Double = 0

    var selectedDuration: Double { trimEnd - trimStart }

    let player: AVPlayer
    private var timeObserver: Any?

    init(asset: AVURLAsset) {
        self.asset = asset
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.player.actionAtItemEnd = .pause
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
    }

    func loadDuration() async {
        do {
            let dur = try await asset.load(.duration)
            videoDuration = CMTimeGetSeconds(dur)
            trimEnd = min(maxDuration, videoDuration)
            setupTimeObserver()
            seekToTrimStart()
        } catch {
            videoDuration = 0
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            Task { @MainActor in
                self.currentPlaybackTime = seconds
                if seconds >= self.trimEnd {
                    self.player.pause()
                    self.isPlaying = false
                    self.seekToTrimStart()
                }
            }
        }
    }

    func seekToTrimStart() {
        player.seek(
            to: CMTime(seconds: trimStart, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentPlaybackTime = trimStart
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            if currentPlaybackTime >= trimEnd || currentPlaybackTime < trimStart {
                seekToTrimStart()
            }
            player.play()
        }
        isPlaying.toggle()
    }

    func updateTrimStart(_ newStart: Double) {
        let clamped = max(0, min(newStart, trimEnd - 1))
        trimStart = clamped
        // Enforce max duration
        if trimEnd - trimStart > maxDuration {
            trimEnd = trimStart + maxDuration
        }
        seekToTrimStart()
    }

    func updateTrimEnd(_ newEnd: Double) {
        let clamped = min(videoDuration, max(newEnd, trimStart + 1))
        trimEnd = clamped
        // Enforce max duration
        if trimEnd - trimStart > maxDuration {
            trimStart = trimEnd - maxDuration
        }
        seekToTrimStart()
    }

    func generateFrameStrip(width: CGFloat) async {
        let thumbWidth: CGFloat = 44
        let count = max(Int(width / thumbWidth), 8)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 80, height: 80)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        var images: [UIImage] = []
        let interval = videoDuration / Double(count)

        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                images.append(UIImage())
            }
        }

        frameThumbnails = images
    }

    func exportTrimmedVideo() async throws -> URL {
        isExporting = true
        exportProgress = 0

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).mp4")

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let preferredPresets = [
            AVAssetExportPreset3840x2160,
            AVAssetExportPreset1920x1080,
            AVAssetExportPresetHighestQuality
        ]
        let presetName = preferredPresets.first { compatiblePresets.contains($0) }
            ?? AVAssetExportPresetHighestQuality

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: presetName
        ) else {
            isExporting = false
            throw VideoFilterError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: trimStart, preferredTimescale: 600),
            duration: CMTime(seconds: selectedDuration, preferredTimescale: 600)
        )

        let progressTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let p = Double(exportSession.progress)
                await MainActor.run { self?.exportProgress = p }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        await exportSession.export()
        progressTask.cancel()

        isExporting = false

        guard exportSession.status == .completed else {
            if exportSession.status == .cancelled {
                throw VideoFilterError.cancelled
            }
            throw VideoFilterError.exportFailed(
                exportSession.error?.localizedDescription ?? "Unknown trim error"
            )
        }

        return outputURL
    }
}

// MARK: - VideoTrimmerView

struct VideoTrimmerView: View {
    let videoURL: URL
    let onTrimmed: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel: VideoTrimmerViewModel
    @State private var exportError: String?

    init(videoURL: URL, onTrimmed: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.videoURL = videoURL
        self.onTrimmed = onTrimmed
        self.onCancel = onCancel
        let asset = AVURLAsset(url: videoURL)
        _viewModel = StateObject(wrappedValue: VideoTrimmerViewModel(asset: asset))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Video Preview
                    TrimmerVideoPreview(player: viewModel.player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .onTapGesture { viewModel.togglePlayback() }
                        .overlay(alignment: .center) {
                            if !viewModel.isPlaying {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.7))
                                    .allowsHitTesting(false)
                            }
                        }

                    Spacer().frame(height: 16)

                    // Duration label
                    HStack {
                        Text(formatDuration(viewModel.selectedDuration))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("selected of")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatDuration(viewModel.videoDuration))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 12)

                    // Trim timeline
                    TrimTimelineView(viewModel: viewModel)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Playback controls
                    Button { viewModel.togglePlayback() } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 16)

                    Spacer()
                }
            }
            .navigationTitle("Trim Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.darkBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.white.opacity(0.8))
                        .disabled(viewModel.isExporting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    doneButton
                }
            }
            .alert("Trim Failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "An unknown error occurred.")
            }
        }
        .task {
            await viewModel.loadDuration()
            await viewModel.generateFrameStrip(width: UIScreen.main.bounds.width - 48)
        }
    }

    private var doneButton: some View {
        Button {
            Task {
                do {
                    viewModel.player.pause()
                    viewModel.isPlaying = false
                    let trimmedURL = try await viewModel.exportTrimmedVideo()
                    onTrimmed(trimmedURL)
                } catch {
                    exportError = error.localizedDescription
                }
            }
        } label: {
            if viewModel.isExporting {
                HStack(spacing: 6) {
                    ProgressView().tint(.white)
                    Text("\(Int(viewModel.exportProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.purpleAccent.opacity(0.6))
                .clipShape(Capsule())
            } else {
                Text("Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppColors.purpleAccent)
                    .clipShape(Capsule())
            }
        }
        .disabled(viewModel.isExporting)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - TrimTimelineView

private struct TrimTimelineView: View {
    @ObservedObject var viewModel: VideoTrimmerViewModel

    private let stripHeight: CGFloat = 56
    private let handleWidth: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Frame thumbnails
                frameStrip(width: width)

                // Dim overlay outside selection
                leftOverlay(width: width)
                rightOverlay(width: width)

                // Selection border (top and bottom)
                selectionBorder(width: width)

                // Left handle
                handleView(isLeft: true)
                    .position(x: startX(in: width), y: stripHeight / 2)
                    .gesture(dragGesture(for: .start, totalWidth: width))

                // Right handle
                handleView(isLeft: false)
                    .position(x: endX(in: width), y: stripHeight / 2)
                    .gesture(dragGesture(for: .end, totalWidth: width))

                // Playhead
                if viewModel.isPlaying || viewModel.currentPlaybackTime > viewModel.trimStart {
                    playheadLine(width: width)
                }
            }
        }
        .frame(height: stripHeight)
    }

    // MARK: - Frame strip

    private func frameStrip(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.frameThumbnails.enumerated()), id: \.offset) { _, image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width / CGFloat(max(viewModel.frameThumbnails.count, 1)),
                           height: stripHeight)
                    .clipped()
            }
        }
        .frame(width: width, height: stripHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Overlays

    private func leftOverlay(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .frame(width: max(0, startX(in: width) - handleWidth / 2), height: stripHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)
    }

    private func rightOverlay(width: CGFloat) -> some View {
        let rx = endX(in: width) + handleWidth / 2
        return Rectangle()
            .fill(Color.black.opacity(0.55))
            .frame(width: max(0, width - rx), height: stripHeight)
            .offset(x: rx)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)
    }

    // MARK: - Selection border

    private func selectionBorder(width: CGFloat) -> some View {
        let sx = startX(in: width) + handleWidth / 2
        let ex = endX(in: width) - handleWidth / 2
        let selWidth = max(0, ex - sx)

        return VStack {
            Rectangle().fill(Color.white).frame(height: 2)
            Spacer()
            Rectangle().fill(Color.white).frame(height: 2)
        }
        .frame(width: selWidth, height: stripHeight)
        .offset(x: sx - (width - selWidth) / 2)
        .allowsHitTesting(false)
    }

    // MARK: - Handles

    private func handleView(isLeft: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: handleWidth, height: stripHeight)
            .overlay {
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 8, height: 1.5)
                    }
                }
            }
            .contentShape(Rectangle().size(width: 44, height: stripHeight + 20))
    }

    // MARK: - Playhead

    private func playheadLine(width: CGFloat) -> some View {
        let fraction = viewModel.videoDuration > 0
            ? viewModel.currentPlaybackTime / viewModel.videoDuration
            : 0
        let x = CGFloat(fraction) * width

        return Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: stripHeight + 8)
            .position(x: x, y: stripHeight / 2)
            .allowsHitTesting(false)
    }

    // MARK: - Drag gestures

    private enum TrimHandle { case start, end }

    private func dragGesture(for handle: TrimHandle, totalWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.player.pause()
                viewModel.isPlaying = false
                let seconds = Double(value.location.x / totalWidth) * viewModel.videoDuration
                switch handle {
                case .start: viewModel.updateTrimStart(seconds)
                case .end: viewModel.updateTrimEnd(seconds)
                }
            }
    }

    // MARK: - Position helpers

    private func startX(in width: CGFloat) -> CGFloat {
        guard viewModel.videoDuration > 0 else { return 0 }
        return CGFloat(viewModel.trimStart / viewModel.videoDuration) * width
    }

    private func endX(in width: CGFloat) -> CGFloat {
        guard viewModel.videoDuration > 0 else { return width }
        return CGFloat(viewModel.trimEnd / viewModel.videoDuration) * width
    }
}

// MARK: - TrimmerVideoPreview

private struct TrimmerVideoPreview: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
