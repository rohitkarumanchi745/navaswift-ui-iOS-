import Foundation
import NavCore

/// Tracks notification lifecycle outcomes for telemetry alignment with the server's outcome table.
/// Records events: delivered, opened (tapped), and deeplinked (navigated to content).
@MainActor
public enum NotificationOutcome {

    public enum Event: String, Sendable {
        /// Notification was delivered to the device (foreground presentation).
        case delivered
        /// User tapped the notification.
        case opened
        /// Navigation completed to the deep-linked content.
        case deeplinked
    }

    /// Records a notification outcome via NetworkMetrics.
    /// - Parameters:
    ///   - event: The lifecycle event (delivered/opened/deeplinked).
    ///   - type: The notification type from the payload (e.g. "message", "match").
    ///   - matchId: Optional match ID for context.
    public static func record(event: Event, type: String, matchId: String? = nil) {
        let metric = RequestMetric(
            endpoint: "notification/\(event.rawValue)",
            method: "EVENT",
            statusCode: 200,
            latencyMs: 0,
            errorMessage: nil,
            timestamp: Date()
        )
        NetworkMetrics.shared.record(metric)

        NavLog.info(
            "Notification outcome: \(event.rawValue) type=\(type) matchId=\(matchId ?? "none")",
            category: .general
        )
    }
}
