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

// MARK: - Music Start Offset Sheet

private struct MusicStartOffsetSheet: View {
    let song: Song
    @Binding var startSeconds: Double
    let onConfirm: () -> Void
    let onPreviewAt: (Double) -> Void

    private var maxStartSeconds: Double {
        guard let duration = song.duration else { return 30 }
        return max(0, duration - 5) // leave at least 5s of audio
    }

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

            // Start offset slider
            VStack(spacing: 8) {
                Text("Start at")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Text(formatTime(startSeconds))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.purpleAccent)
                        .frame(width: 50, alignment: .leading)

                    Slider(value: $startSeconds, in: 0...maxStartSeconds, step: 0.5)
                        .tint(AppColors.purpleAccent)

                    if let duration = song.duration {
                        Text(formatTime(duration))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                // Preview from offset button
                if song.previewAssets?.first?.url != nil {
                    Button {
                        onPreviewAt(startSeconds)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Preview from \(formatTime(startSeconds))")
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
    }

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
