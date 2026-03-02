import Foundation

enum AppEnvironment: String {
    case development
    case production
}

struct AppConfig {
    static let shared = AppConfig()

    let environment: AppEnvironment
    let apiBaseURL: String
    let wsBaseURL: String

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

    var isDevelopment: Bool { environment == .development }
    var isProduction: Bool { environment == .production }
}
