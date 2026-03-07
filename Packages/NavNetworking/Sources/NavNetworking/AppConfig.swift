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
}
