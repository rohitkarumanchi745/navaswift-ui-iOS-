import Foundation

public struct ReelMusic: Codable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let artworkURL: String?
    public let previewURL: String?
    public let durationMs: Int?
    public let startMs: Int?

    public init(
        id: String,
        title: String,
        artist: String,
        artworkURL: String? = nil,
        previewURL: String? = nil,
        durationMs: Int? = nil,
        startMs: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.durationMs = durationMs
        self.startMs = startMs
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, artist
        case artworkURL = "artwork_url"
        case previewURL = "preview_url"
        case durationMs = "duration_ms"
        case startMs = "start_ms"
    }
}
