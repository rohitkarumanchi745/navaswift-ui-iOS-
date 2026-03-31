import SwiftUI
import MusicKit
import AVFoundation
import NavCore
import NavNetworking

// MARK: - MusicSearchView

struct MusicSearchView: View {
    let onSelect: (ReelMusic) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var searchTask: Task<Void, Never>?
    @State private var previewPlayer: AVPlayer?
    @State private var playingSongID: MusicItemID?
    @State private var noPreviewAlert = false
    @State private var selectedSongForTrim: Song?
    @State private var trimStartSeconds: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                Group {
                    switch authStatus {
                    case .authorized:
                        searchContent
                    case .denied, .restricted:
                        deniedView
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .navigationTitle("Add Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.darkBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .task {
            authStatus = await MusicAuthorization.request()
        }
        .onDisappear {
            previewPlayer?.pause()
            previewPlayer = nil
        }
        .alert("No Preview Available", isPresented: $noPreviewAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This song doesn't have a preview clip. The music metadata will be saved, but no audio will be mixed into your reel.")
        }
        .sheet(item: $selectedSongForTrim) { song in
            MusicStartOffsetSheet(
                song: song,
                startSeconds: $trimStartSeconds,
                onConfirm: { confirmSong(song) },
                onPreviewAt: { seconds in previewAt(song: song, seconds: seconds) }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.darkBg)
        }
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Search songs…", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .tint(AppColors.purpleAccent)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        songs = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .onChange(of: searchText) { _, text in
                searchTask?.cancel()
                guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                    songs = []
                    return
                }
                searchTask = Task {
                    // Debounce
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await performSearch(term: text)
                }
            }

            if isSearching {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if songs.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No results found")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else if songs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Search for a song to add to your reel")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(songs, id: \.id) { song in
                            MusicSearchRow(
                                song: song,
                                isPlaying: playingSongID == song.id,
                                hasPreview: song.previewAssets?.first?.url != nil,
                                onPreview: { togglePreview(song: song) },
                                onSelect: { selectSong(song) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Denied View

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("Music Access Required")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Enable Apple Music access in Settings to add music to your reels.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(AppColors.purpleAccent)
            .clipShape(Capsule())
        }
        .padding(32)
    }

    // MARK: - Search

    private func performSearch(term: String) async {
        isSearching = true
        defer { isSearching = false }

        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            guard !Task.isCancelled else { return }
            songs = Array(response.songs)
        } catch {
            if !Task.isCancelled {
                songs = []
            }
        }
    }

    // MARK: - Preview Playback

    private func togglePreview(song: Song) {
        if playingSongID == song.id {
            previewPlayer?.pause()
            previewPlayer = nil
            playingSongID = nil
            return
        }

        guard let previewURL = song.previewAssets?.first?.url else {
            noPreviewAlert = true
            return
        }

        previewPlayer?.pause()
        let player = AVPlayer(url: previewURL)
        previewPlayer = player
        playingSongID = song.id
        player.play()
    }

    // MARK: - Selection

    private func selectSong(_ song: Song) {
        previewPlayer?.pause()
        playingSongID = nil
        trimStartSeconds = 0
        selectedSongForTrim = song
    }

    private func confirmSong(_ song: Song) {
        previewPlayer?.pause()
        previewPlayer = nil

        let artworkURLString: String? = {
            guard let artwork = song.artwork else { return nil }
            let url = artwork.url(width: 600, height: 600)
            return url?.absoluteString
        }()

        let previewURLString = song.previewAssets?.first?.url?.absoluteString

        let durationMs: Int? = {
            guard let duration = song.duration else { return nil }
            return Int(duration * 1000)
        }()

        let music = ReelMusic(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            artworkURL: artworkURLString,
            previewURL: previewURLString,
            durationMs: durationMs,
            startMs: Int(trimStartSeconds * 1000)
        )

        selectedSongForTrim = nil
        onSelect(music)
        dismiss()
    }

    private func previewAt(song: Song, seconds: Double) {
        guard let previewURL = song.previewAssets?.first?.url else { return }
        previewPlayer?.pause()
        let player = AVPlayer(url: previewURL)
        previewPlayer = player
        let seekTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: seekTime) { _ in
            player.play()
        }
    }
}

// MARK: - Song: Identifiable for .sheet(item:)

extension Song: @retroactive Identifiable {}

// MARK: - Music Start Offset Sheet (Instagram-style scrollable waveform trim)

private struct MusicStartOffsetSheet: View {
    let song: Song
    @Binding var startSeconds: Double
    let onConfirm: () -> Void
    let onPreviewAt: (Double) -> Void

    /// Duration of the selected clip (max 30s to match reel limit).
    private let clipDuration: Double = 30.0

    /// The actual duration of the preview clip (loaded async on appear).
    /// Apple Music previews are typically ~30 seconds — the trim UI must be
    /// limited to this range since we only have the preview, not the full song.
    @State private var previewDuration: Double?

    /// Effective duration used for the waveform — preview clip duration once
    /// loaded, otherwise falls back to the full song duration.
    private var effectiveDuration: Double {
        previewDuration ?? (song.duration ?? 30)
    }

    /// How far the start offset can go before the clip would exceed the available audio.
    private var maxStartSeconds: Double {
        max(0, effectiveDuration - clipDuration)
    }

    /// Number of bars in the waveform strip (1 bar per ~0.5s).
    private var barCount: Int { max(1, Int(effectiveDuration * 2)) }

    /// Points per second — controls how wide the waveform strip is.
    private let ptsPerSecond: CGFloat = 8

    /// Total width of the scrollable waveform in points.
    private var totalWidth: CGFloat { CGFloat(effectiveDuration) * ptsPerSecond }

    /// Width of the highlighted selection window.
    private var windowWidth: CGFloat { CGFloat(min(clipDuration, effectiveDuration)) * ptsPerSecond }

    @State private var isPreviewing = false
    @State private var dragBase: Double?

    var body: some View {
        VStack(spacing: 20) {
            // Song header
            HStack(spacing: 12) {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }

            // Trim section
            VStack(spacing: 10) {
                // Time labels
                HStack {
                    Text(formatTime(startSeconds))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.purpleAccent)
                    Spacer()
                    let endTime = min(startSeconds + clipDuration, effectiveDuration)
                    Text(formatTime(endTime))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.purpleAccent)
                }

                // Scrollable waveform with selection window
                GeometryReader { geo in
                    let containerWidth = geo.size.width
                    // The strip scrolls behind a fixed selection window centered in the container
                    let fixedWindowX = (containerWidth - windowWidth) / 2
                    // Clamp so the strip doesn't scroll past its boundaries
                    let maxOffset = totalWidth - windowWidth
                    let currentOffset = maxStartSeconds > 0
                        ? CGFloat(startSeconds / maxStartSeconds) * maxOffset
                        : 0
                    let stripX = fixedWindowX - currentOffset

                    ZStack(alignment: .leading) {
                        // Dimmed waveform bars (full song)
                        waveformBars(opacity: 0.15)
                            .frame(width: totalWidth, height: 48)
                            .offset(x: stripX)

                        // Highlighted waveform bars (selection window only via mask)
                        waveformBars(opacity: 1.0)
                            .frame(width: totalWidth, height: 48)
                            .offset(x: stripX)
                            .mask {
                                Rectangle()
                                    .frame(width: windowWidth, height: 48)
                                    .offset(x: fixedWindowX)
                                    .frame(width: containerWidth, alignment: .leading)
                            }

                        // Selection window border
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(AppColors.purpleAccent, lineWidth: 2)
                            .frame(width: windowWidth, height: 52)
                            .offset(x: fixedWindowX)

                        // Left/Right handles
                        handleGrip()
                            .offset(x: fixedWindowX - 2)
                        handleGrip()
                            .offset(x: fixedWindowX + windowWidth - 4)
                    }
                    .frame(width: containerWidth, height: 52)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                // Capture the start position on first drag callback
                                if dragBase == nil { dragBase = startSeconds }
                                // Map pixel translation to seconds
                                let ptsPerSec = totalWidth / CGFloat(effectiveDuration)
                                let delta = -Double(value.translation.width) / Double(ptsPerSec)
                                let newStart = min(maxStartSeconds, max(0, (dragBase ?? 0) + delta))
                                startSeconds = (newStart * 2).rounded() / 2 // snap to 0.5s
                            }
                            .onEnded { _ in
                                dragBase = nil
                                // Auto-preview the selected section after scrub
                                if song.previewAssets?.first?.url != nil {
                                    onPreviewAt(startSeconds)
                                    isPreviewing = true
                                }
                            }
                    )
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Hint text
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 11))
                    Text("Drag to select which part to use (\(Int(min(clipDuration, effectiveDuration)))s)")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.4))

                // Preview button
                if song.previewAssets?.first?.url != nil {
                    Button {
                        onPreviewAt(startSeconds)
                        isPreviewing.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                            Text(isPreviewing ? "Pause" : "Preview from \(formatTime(startSeconds))")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(AppColors.purpleAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Confirm button
            Button(action: onConfirm) {
                Text("Use This Song")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.purpleAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .task {
            // Load the actual preview clip duration so the trim range matches
            // what's available (Apple Music previews are typically ~30 seconds).
            guard let url = song.previewAssets?.first?.url else { return }
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(duration)
                if seconds > 0 {
                    previewDuration = seconds
                    // Clamp the current selection if it exceeds the preview range
                    if startSeconds > max(0, seconds - clipDuration) {
                        startSeconds = max(0, seconds - clipDuration)
                    }
                }
            }
        }
    }

    // MARK: - Waveform Bars

    /// Generates pseudo-random waveform bars based on bar index (deterministic).
    @ViewBuilder
    private func waveformBars(opacity: Double) -> some View {
        HStack(spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { i in
                // Deterministic pseudo-random height based on index
                let seed = sin(Double(i) * 0.7 + 1.3) * 43758.5453
                let normalised = abs(seed - seed.rounded(.down))
                let height = 6 + normalised * 42 // 6–48 pts
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.purpleAccent.opacity(opacity))
                    .frame(width: 2, height: CGFloat(height))
            }
        }
        .frame(height: 48, alignment: .center)
    }

    // MARK: - Handle Grip

    @ViewBuilder
    private func handleGrip() -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(AppColors.purpleAccent)
            .frame(width: 6, height: 52)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - MusicSearchRow

private struct MusicSearchRow: View {
    let song: Song
    let isPlaying: Bool
    let hasPreview: Bool
    let onPreview: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Artwork
                ZStack {
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                    }
                }
                .frame(width: 48, height: 48)

                // Song info
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(song.artistName)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        if !hasPreview {
                            Text("· No preview")
                                .font(.system(size: 11))
                                .foregroundColor(.orange.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Duration
                if let duration = song.duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Preview button
                Button(action: onPreview) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(
                            isPlaying ? AppColors.purpleAccent :
                            hasPreview ? .white.opacity(0.6) : .white.opacity(0.2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
