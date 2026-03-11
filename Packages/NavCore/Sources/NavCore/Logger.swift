import Foundation
import os

/// Structured logging service with level filtering.
/// Uses os.Logger in production, prints to console in debug.
public enum NavLog {
    public enum Level: Int, Comparable {
        case debug = 0, info = 1, warning = 2, error = 3
        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public enum Category: String {
        case auth, network, chat, store, ui, general
    }

    #if DEBUG
    public static var minimumLevel: Level = .debug
    #else
    public static var minimumLevel: Level = .info
    #endif

    private static let osLog = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nava.app", category: "NAVA")

    public static func debug(_ message: String, category: Category = .general, file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, line: line)
    }

    public static func info(_ message: String, category: Category = .general, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, line: line)
    }

    public static func warning(_ message: String, category: Category = .general, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, line: line)
    }

    public static func error(_ message: String, category: Category = .general, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, line: line)
    }

    private static func log(level: Level, message: String, category: Category, file: String, line: Int) {
        guard level >= minimumLevel else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let prefix = "[\(category.rawValue.uppercased())]"
        let formatted = "\(prefix) \(message) (\(fileName):\(line))"

        switch level {
        case .debug: osLog.debug("\(formatted)")
        case .info:  osLog.info("\(formatted)")
        case .warning: osLog.warning("\(formatted)")
        case .error: osLog.error("\(formatted)")
        }
    }
}
