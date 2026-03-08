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
        apiBaseURL = "http://127.0.0.1:8080"
        wsBaseURL = "ws://127.0.0.1:8080"
        #else
        environment = .production
        // Replace with your production server URL before App Store submission
        apiBaseURL = "https://api.nava.app"
        wsBaseURL = "wss://api.nava.app"
        #endif
    }

    public var isDevelopment: Bool { environment == .development }
    public var isProduction: Bool { environment == .production }

    /// Resolves a photo path to a full URL.
    /// Paths starting with "/" are treated as relative to the API base URL.
    /// Paths that are already full URLs (http/https) are returned as-is.
    public static func resolvePhotoURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let base = shared.apiBaseURL
        return URL(string: "\(base)\(path)")
    }
}
