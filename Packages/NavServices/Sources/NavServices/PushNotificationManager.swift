import Foundation
import UIKit
import UserNotifications
import NavCore
import NavNetworking

/// Manages push notification registration, permissions, and device token lifecycle.
/// Coordinates with the backend device registry at `/api/notifications/register-device`.
@MainActor
public class PushNotificationManager: NSObject, ObservableObject {
    @Published public var isAuthorized = false
    @Published public var deviceToken: String?
    /// Set when a push notification is tapped; MainTabView observes this to navigate.
    @Published public var pendingDeepLink: DeepLink?
    /// True while a deep-link prefetch is in progress; UI can show a loading hint.
    /// Only becomes true after a short delay to avoid flashing on fast networks.
    @Published public var isPrefetchingDeepLink = false

    private var pendingToken: String?
    private var prefetchShowTask: Task<Void, Never>?

    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - Permission

    public func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            if granted {
                NavLog.info("Push notification permission granted", category: .general)
                await registerForRemoteNotifications()
            } else {
                NavLog.info("Push notification permission denied", category: .general)
            }
        } catch {
            NavLog.error("Push notification permission request failed: \(error.localizedDescription)", category: .general)
        }
    }

    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Token Handling

    /// Called from AppDelegate when APNs returns a device token.
    public func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        NavLog.info("APNs device token received: \(token.prefix(8))...", category: .general)
        registerTokenWithBackend(token)
    }

    /// Called from AppDelegate when APNs registration fails.
    public func didFailToRegisterForRemoteNotifications(error: Error) {
        NavLog.error("APNs registration failed: \(error.localizedDescription)", category: .general)
    }

    /// Sends the device token to the backend device registry.
    /// Retries once on failure.
    private func registerTokenWithBackend(_ token: String) {
        Task {
            struct RegisterResponse: Decodable {
                let success: Bool?
            }

            let body: [String: Any] = [
                "token": token,
                "platform": "ios",
                "device_id": await UIDevice.current.identifierForVendor?.uuidString ?? "",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            ]

            do {
                let _: RegisterResponse = try await APIService.shared.post(
                    path: "/api/notifications/register-device",
                    body: body
                )
                NavLog.info("Device token registered with backend", category: .network)
            } catch {
                NavLog.warning("Failed to register device token with backend: \(error.localizedDescription)", category: .network)
                // Retry once after delay
                try? await Task.sleep(for: .seconds(5))
                do {
                    let _: RegisterResponse = try await APIService.shared.post(
                        path: "/api/notifications/register-device",
                        body: body
                    )
                    NavLog.info("Device token registered with backend (retry)", category: .network)
                } catch {
                    NavLog.error("Device token registration failed after retry: \(error.localizedDescription)", category: .network)
                }
            }
        }
    }

    /// Unregisters the device token from the backend on logout.
    public func unregisterToken() {
        guard let token = deviceToken else { return }
        Task {
            struct UnregisterResponse: Decodable {
                let success: Bool?
            }
            do {
                let _: UnregisterResponse = try await APIService.shared.post(
                    path: "/api/notifications/unregister-device",
                    body: ["token": token]
                )
                NavLog.info("Device token unregistered from backend", category: .network)
            } catch {
                NavLog.warning("Failed to unregister device token: \(error.localizedDescription)", category: .network)
            }
        }
    }

    // MARK: - Badge Management

    public func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error {
                NavLog.debug("Failed to clear badge: \(error.localizedDescription)", category: .general)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground — show as banner.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let type = userInfo["type"] as? String ?? "unknown"
        let matchId = userInfo["match_id"] as? String
        Task { @MainActor in
            NotificationOutcome.record(event: .delivered, type: type, matchId: matchId)
        }
        completionHandler([.banner, .badge, .sound])
    }

    /// Handle notification tap — navigate to relevant screen.
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            let type = userInfo["type"] as? String ?? "unknown"
            let matchId = userInfo["match_id"] as? String
            NotificationOutcome.record(event: .opened, type: type, matchId: matchId)
            NavLog.debug("Notification tapped: \(userInfo)", category: .general)
            handleNotificationAction(userInfo: userInfo)
        }
        completionHandler()
    }

    @MainActor
    private func handleNotificationAction(userInfo: [AnyHashable: Any]) {
        // Parse the notification payload into a deep link for navigation
        guard let deepLink = DeepLink.from(userInfo: userInfo) else {
            // Also post NotificationCenter for any other observers
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
            return
        }

        let notifType = userInfo["type"] as? String ?? "unknown"
        let notifMatchId = userInfo["match_id"] as? String
        NavLog.info("Deep link parsed from notification: \(deepLink)", category: .general)

        // Prefetch relevant data before navigating.
        // The indicator only appears after 300ms to avoid flashing on fast networks.
        // Once visible, it stays for at least 400ms so the user can read it.
        Task {
            let showDelay: UInt64 = 300_000_000 // 300ms
            let minDisplay: UInt64 = 400_000_000 // 400ms

            // Schedule delayed indicator show
            prefetchShowTask?.cancel()
            prefetchShowTask = Task {
                try? await Task.sleep(nanoseconds: showDelay)
                if !Task.isCancelled {
                    isPrefetchingDeepLink = true
                }
            }

            await prefetchForDeepLink(deepLink)

            // If the indicator never showed, cancel the delayed show
            prefetchShowTask?.cancel()
            prefetchShowTask = nil

            if isPrefetchingDeepLink {
                // Indicator is visible — hold it for minimum display time
                try? await Task.sleep(nanoseconds: minDisplay)
            }
            isPrefetchingDeepLink = false
            pendingDeepLink = deepLink

            NotificationOutcome.record(event: .deeplinked, type: notifType, matchId: notifMatchId)
        }

        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }

    /// Prewarns data for a deep link before navigation occurs.
    /// Tracks prefetch latency and success/failure via NetworkMetrics.
    @MainActor
    private func prefetchForDeepLink(_ deepLink: DeepLink) async {
        let endpoint: String
        let query: String
        let variables: [String: String]

        switch deepLink {
        case .chat(let matchId) where !matchId.isEmpty:
            endpoint = "prefetch/conversation"
            query = """
            query Conversation($matchId: ID!) {
                conversation(matchId: $matchId) {
                    id content senderId createdAt
                }
            }
            """
            variables = ["matchId": matchId]

        case .matchDetail(let matchId):
            endpoint = "prefetch/match-detail"
            query = """
            query MatchDetail($matchId: ID!) {
                matches { id partner { id name age photos } isMutual }
            }
            """
            variables = ["matchId": matchId]

        default:
            return
        }

        NavLog.debug("Prefetching \(endpoint)", category: .network)
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let _: [String: Any] = try await APIService.shared.graphQL(
                query: query,
                variables: variables
            )
            let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
            NetworkMetrics.shared.recordSuccess(
                endpoint: endpoint,
                method: "GRAPHQL",
                statusCode: 200,
                latencyMs: latency
            )
            NavLog.debug("Prefetch complete for \(endpoint) in \(Int(latency))ms", category: .network)
        } catch {
            let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
            NetworkMetrics.shared.recordError(
                endpoint: endpoint,
                method: "GRAPHQL",
                statusCode: nil,
                latencyMs: latency,
                error: error.localizedDescription
            )
            NavLog.debug("Prefetch failed for \(endpoint): \(error.localizedDescription)", category: .network)
            // Navigation proceeds even if prefetch fails
        }
    }
}

// MARK: - Notification Name
public extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("nava.pushNotificationTapped")
}
