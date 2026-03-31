import SwiftUI
import NavCore
import NavServices

struct MusicTasteView: View {
    @EnvironmentObject var musicService: MusicTasteSyncService
    @EnvironmentObject var spotifyAuth: SpotifyAuthManager

    private let genreColors: [Color] = [
        Color(hex: "FF6B6B"), Color(hex: "4ECDC4"), Color(hex: "45B7D1"),
        Color(hex: "96CEB4"), Color(hex: "FFEAA7"), Color(hex: "DDA0DD"),
        Color(hex: "98D8C8"), Color(hex: "F7DC6F"), Color(hex: "BB8FCE"),
        Color(hex: "85C1E9"),
    ]

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if let taste = musicService.musicTaste {
                if taste.genres.isEmpty && taste.artists.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            // Spotify connection status
                            if spotifyAuth.isConnected {
                                spotifyStatusSection
                            } else {
                                spotifyConnectButton
                            }

                            if !taste.genres.isEmpty {
                                genresSection(taste.genres)
                            }
                            if !taste.artists.isEmpty {
                                artistsSection(taste.artists)
                            }
                        }
                        .padding(20)
                    }
                }
            } else if musicService.isFetchingTaste {
                ProgressView()
                    .tint(AppColors.purpleAccent)
                    .scaleEffect(1.2)
            } else {
                emptyState
            }
        }
        .navigationTitle("Music Taste")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if musicService.musicTaste == nil {
                await musicService.fetchMyTaste()
            }
        }
        .onChange(of: spotifyAuth.isConnected) { _, connected in
            if connected {
                Task { await musicService.syncSpotifyNow() }
            }
        }
        .alert("Spotify Error", isPresented: .init(
            get: { spotifyAuth.authError != nil },
            set: { if !$0 { spotifyAuth.authError = nil } }
        )) {
            Button("OK") { spotifyAuth.authError = nil }
        } message: {
            Text(spotifyAuth.authError ?? "")
        }
    }

    // MARK: - Spotify Connect

    private var spotifyConnectButton: some View {
        Button {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                spotifyAuth.startAuth(presentationAnchor: window)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Connect Spotify")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(hex: "1DB954"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(spotifyAuth.isAuthenticating)
        .overlay {
            if spotifyAuth.isAuthenticating {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1DB954").opacity(0.7))
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
    }

    private var spotifyStatusSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "1DB954"))
            Text("Spotify Connected")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button("Disconnect") {
                spotifyAuth.disconnect()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hex: "FF6B6B"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Genres

    private func genresSection(_ genres: [MusicTasteResponse.MusicGenreItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Genres")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            FlowLayout(spacing: 10) {
                ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                    let color = genreColors[index % genreColors.count]
                    HStack(spacing: 6) {
                        Text(genre.name)
                            .font(.system(size: 14, weight: .medium))

                        if let count = genre.count, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(color.opacity(0.8))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.2))
                    .overlay(
                        Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Artists

    private func artistsSection(_ artists: [MusicTasteResponse.MusicArtistItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Artists")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { artist in
                        VStack(spacing: 8) {
                            Image(systemName: "music.mic")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: "FF8A9E"))
                                .frame(width: 56, height: 56)
                                .background(Color(hex: "FF8A9E").opacity(0.15))
                                .clipShape(Circle())

                            Text(artist.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 72)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "FF8A9E").opacity(0.5))

            Text("No Music Data Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Connect a music service to sync your taste automatically.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !spotifyAuth.isConnected {
                spotifyConnectButton
                    .padding(.horizontal, 40)
            }
        }
    }
}
