import Foundation

// MARK: - Music Sync (POST /music/sync)

public struct MusicSyncResponse: Codable {
    public let success: Bool?
    public let message: String?
}

// MARK: - Music Taste (GET /music/taste)

public struct MusicTasteResponse: Codable {
    public let genres: [MusicGenreItem]
    public let artists: [MusicArtistItem]

    public struct MusicGenreItem: Codable, Identifiable, Hashable {
        public var id: String { name }
        public let name: String
        public let count: Int?
    }

    public struct MusicArtistItem: Codable, Identifiable, Hashable {
        public let id: String
        public let name: String
        public let playCount: Int?

        private enum CodingKeys: String, CodingKey {
            case id, name
            case playCount = "play_count"
        }
    }
}

// MARK: - Music Compatibility (GET /music/compatibility/:id)

public struct MusicCompatibilityResponse: Codable {
    public let score: Double
    public let sharedGenres: [String]
    public let sharedArtists: [String]

    private enum CodingKeys: String, CodingKey {
        case score
        case sharedGenres = "shared_genres"
        case sharedArtists = "shared_artists"
    }
}
