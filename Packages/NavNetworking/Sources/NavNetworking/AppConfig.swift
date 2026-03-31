import Foundation

public enum AppEnvironment: String {
    case development
    case production
}

public struct AppConfig {
    public static let shared = AppConfig()

    public let environment: AppEnvironment
    public let apiBaseURL: String
    public let wsBaseURL: String

    private init() {
        #if DEBUG
        environment = .development
        apiBaseURL = "https://nava-production-cb66.up.railway.app"
        wsBaseURL = "wss://nava-production-cb66.up.railway.app"
        #else
        environment = .production
        apiBaseURL = "https://nava-production-cb66.up.railway.app"
        wsBaseURL = "wss://nava-production-cb66.up.railway.app"
        #endif
    }

    public var isDevelopment: Bool { environment == .development }
    public var isProduction: Bool { environment == .production }

    /// Resolves a photo path to a full URL.
    /// Paths starting with "/" are treated as relative to the API base URL.
    /// Paths that are already full URLs (http/https) are returned as-is.
    public static func resolvePhotoURL(_ path: String?) -> URL? {
        resolveMediaURL(path)
    }

    /// Resolves any media path (photo, video, etc.) to a full URL.
    /// Paths starting with "/" are treated as relative to the API base URL.
    /// Paths that are already full URLs (http/https) are returned as-is.
    public static func resolveMediaURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let base = shared.apiBaseURL
        let separator = path.hasPrefix("/") ? "" : "/"
        return URL(string: "\(base)\(separator)\(path)")
    }
}
