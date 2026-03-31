import Foundation
import MusicKit
import NavCore
import NavNetworking

@MainActor
public class MusicTasteSyncService: ObservableObject {

    // MARK: - Published State

    @Published public var musicTaste: MusicTasteResponse?
    @Published public var isSyncing = false
    @Published public var isFetchingTaste = false

    // MARK: - Spotify Integration

    private var spotifyAuth: SpotifyAuthManager?

    /// Wire the Spotify auth manager so syncs can pull from both sources.
    public func setSpotifyAuth(_ auth: SpotifyAuthManager) {
        self.spotifyAuth = auth
    }

    // MARK: - Throttling

    private let lastSyncKey = "music_taste_last_sync"
    private let syncIntervalSeconds: TimeInterval = 86400

    // MARK: - Init

    public init() {
        if let cached = LocalCache.shared.load(MusicTasteResponse.self, forKey: .musicTaste) {
            musicTaste = cached
        }
    }

    // MARK: - Sync (Dual Source)

    /// Requests MusicKit authorization and syncs the user's library genres/artists
    /// from both Apple Music and Spotify (if connected).
    /// Throttled to once per 24 hours.
    public func syncIfNeeded() async {
        guard !isSyncing else { return }
        guard shouldSync() else {
            NavLog.debug("Music sync skipped — last sync was recent", category: .general)
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var allGenres: [String] = []
        var allArtists: [String] = []

        // Source 1: Apple Music
        if let appleData = await fetchAppleMusicData() {
            allGenres.append(contentsOf: appleData.genres)
            allArtists.append(contentsOf: appleData.artists)
        }

        // Source 2: Spotify
        if let spotifyData = await fetchSpotifyData() {
            allGenres.append(contentsOf: spotifyData.genres)
            allArtists.append(contentsOf: spotifyData.artists)
        }

        guard !allGenres.isEmpty || !allArtists.isEmpty else {
            NavLog.debug("No music data from any source, skipping sync", category: .general)
            return
        }

        let uniqueGenres = Array(deduplicate(allGenres).prefix(10))
        let uniqueArtists = Array(deduplicate(allArtists).prefix(10))

        do {
            let _: MusicSyncResponse = try await APIService.shared.post(
                path: "/music/sync",
                body: [
                    "genres": uniqueGenres,
                    "artists": uniqueArtists,
                ]
            )

            markSynced()
            NavLog.info("Music taste synced: \(uniqueGenres.count) genres, \(uniqueArtists.count) artists", category: .general)

            await fetchMyTaste()
        } catch {
            NavLog.warning("Music sync failed: \(error.localizedDescription)", category: .network)
        }
    }

    /// Force-syncs immediately after the user connects Spotify (bypasses 24h throttle).
    public func syncSpotifyNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        var allGenres: [String] = []
        var allArtists: [String] = []

        if let spotifyData = await fetchSpotifyData() {
            allGenres.append(contentsOf: spotifyData.genres)
            allArtists.append(contentsOf: spotifyData.artists)
        }

        if let appleData = await fetchAppleMusicData() {
            allGenres.append(contentsOf: appleData.genres)
            allArtists.append(contentsOf: appleData.artists)
        }

        guard !allGenres.isEmpty || !allArtists.isEmpty else {
            NavLog.debug("No music data available for Spotify immediate sync", category: .general)
            return
        }

        let uniqueGenres = Array(deduplicate(allGenres).prefix(10))
        let uniqueArtists = Array(deduplicate(allArtists).prefix(10))

        do {
            let _: MusicSyncResponse = try await APIService.shared.post(
                path: "/music/sync",
                body: [
                    "genres": uniqueGenres,
                    "artists": uniqueArtists,
                ]
            )

            markSynced()
            NavLog.info("Spotify immediate sync: \(uniqueGenres.count) genres, \(uniqueArtists.count) artists", category: .general)

            await fetchMyTaste()
        } catch {
            NavLog.warning("Spotify immediate sync failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Apple Music Data

    private func fetchAppleMusicData() async -> (genres: [String], artists: [String])? {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            NavLog.debug("MusicKit not authorized, skipping Apple Music", category: .general)
            return nil
        }

        do {
            var artistRequest = MusicLibraryRequest<Artist>()
            artistRequest.limit = 100
            let artistResponse = try await artistRequest.response()
            let artistNames = artistResponse.items.map(\.name)

            var songRequest = MusicLibraryRequest<Song>()
            songRequest.limit = 200
            let songResponse = try await songRequest.response()

            var genreCounts: [String: Int] = [:]
            for song in songResponse.items {
                for genre in song.genreNames {
                    genreCounts[genre, default: 0] += 1
                }
            }

            let topGenres = genreCounts
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map(\.key)

            let topArtists = Array(artistNames.prefix(10))
            return (genres: topGenres, artists: topArtists)
        } catch {
            NavLog.warning("Apple Music fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Spotify Data

    private func fetchSpotifyData() async -> (genres: [String], artists: [String])? {
        guard let spotifyAuth, spotifyAuth.isConnected else { return nil }
        guard let token = await spotifyAuth.getAccessToken() else { return nil }

        do {
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/top/artists?limit=10&time_range=medium_term")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                NavLog.warning("Spotify top artists failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .network)
                return nil
            }

            let topArtists = try JSONDecoder().decode(SpotifyTopArtistsResponse.self, from: data)
            let artistNames = topArtists.items.map(\.name)

            var genreCounts: [String: Int] = [:]
            for artist in topArtists.items {
                for genre in artist.genres {
                    genreCounts[genre, default: 0] += 1
                }
            }

            let topGenres = genreCounts
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map(\.key)

            return (genres: topGenres, artists: artistNames)
        } catch {
            NavLog.warning("Spotify data fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Fetch My Taste

    public func fetchMyTaste() async {
        isFetchingTaste = true
        defer { isFetchingTaste = false }

        do {
            let response: MusicTasteResponse = try await APIService.shared.get(
                path: "/music/taste"
            )
            musicTaste = response
            LocalCache.shared.save(response, forKey: .musicTaste)
        } catch {
            NavLog.warning("Fetch music taste failed: \(error.localizedDescription)", category: .network)
            if musicTaste == nil,
               let cached = LocalCache.shared.loadStale(MusicTasteResponse.self, forKey: .musicTaste) {
                musicTaste = cached
            }
        }
    }

    // MARK: - Fetch Compatibility

    public func fetchCompatibility(withUserId userId: String) async -> MusicCompatibilityResponse? {
        do {
            let response: MusicCompatibilityResponse = try await APIService.shared.get(
                path: "/music/compatibility/\(userId)"
            )
            return response
        } catch {
            NavLog.warning("Music compatibility fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Helpers

    private func deduplicate(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { item in
            let lowered = item.lowercased()
            guard !seen.contains(lowered) else { return false }
            seen.insert(lowered)
            return true
        }
    }

    private func shouldSync() -> Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastSync) >= syncIntervalSeconds
    }

    private func markSynced() {
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
    }
}

// MARK: - Spotify API Models

private struct SpotifyTopArtistsResponse: Decodable {
    let items: [SpotifyArtist]

    struct SpotifyArtist: Decodable {
        let name: String
        let genres: [String]
    }
}
