import SwiftUI
import BackgroundTasks
import NavCore
import NavNetworking
import NavServices
import NavFeatures

// MARK: - App Delegate (APNs)

class AppDelegate: NSObject, UIApplicationDelegate {
    var pushManager: PushNotificationManager?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushManager?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushManager?.didFailToRegisterForRemoteNotifications(error: error)
    }

    /// Reconnect the background URL session when the system relaunches the app
    /// to deliver upload completion events.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            ReelUploadService.shared.handleBackgroundSessionEvents(completionHandler: completionHandler)
        }
    }

    /// Handle silent push / background fetch for prewarming badge counts and feeds.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NavLog.debug("Background fetch triggered via silent push", category: .general)

        Task {
            // Prewarm badge counts by fetching matches data
            do {
                let query = """
                query { matches { id isMutual } }
                """
                let _: [String: Any] = try await APIService.shared.graphQL(query: query)
                NavLog.debug("Background fetch: badge data prewarmed", category: .general)
                completionHandler(.newData)
            } catch {
                NavLog.debug("Background fetch failed: \(error.localizedDescription)", category: .general)
                completionHandler(.failed)
            }
        }
    }
}

// MARK: - App

@main
struct navaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var callManager = CallManager()
    @StateObject private var pushManager = PushNotificationManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var reelUploadService = ReelUploadService()
    @StateObject private var flService = FederatedLearningService()
    @StateObject private var musicTasteService = MusicTasteSyncService()
    @StateObject private var contactMatchingService = ContactMatchingService()
    @StateObject private var fitnessService = FitnessService()
    @StateObject private var spotifyAuth = SpotifyAuthManager()
    @StateObject private var stravaAuth = StravaAuthManager()
    @StateObject private var outdoorService = OutdoorService()
    @StateObject private var mapSearchService = MapSearchService()
    @StateObject private var adManager = AdManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register FL background training task — must happen before app finishes launching
        FederatedLearningService.registerBackgroundTaskHandler()

        // Wire APIService metrics into NetworkMetrics
        APIService.shared.onMetric = { metric in
            Task { @MainActor in
                NetworkMetrics.shared.record(RequestMetric(
                    endpoint: metric.endpoint,
                    method: metric.method,
                    statusCode: metric.statusCode,
                    latencyMs: metric.latencyMs,
                    errorMessage: metric.error,
                    timestamp: Date()
                ))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(storeKitManager)
                .environmentObject(callManager)
                .environmentObject(pushManager)
                .environmentObject(networkMonitor)
                .environmentObject(reelUploadService)
                .environmentObject(flService)
                .environmentObject(musicTasteService)
                .environmentObject(contactMatchingService)
                .environmentObject(fitnessService)
                .environmentObject(spotifyAuth)
                .environmentObject(stravaAuth)
                .environmentObject(outdoorService)
                .environmentObject(mapSearchService)
                .environmentObject(adManager)
                .task {
                    // Wire 401 interceptor — refresh token and retry on unauthorized
                    APIService.shared.onUnauthorized = { [weak authManager] in
                        guard let authManager else { return false }
                        return await authManager.refreshAccessToken()
                    }
                    // Connect AppDelegate to PushNotificationManager
                    appDelegate.pushManager = pushManager
                    // Wire logout to unregister push token, clear badge, and reset sync timestamps
                    authManager.onLogout = { [weak pushManager, weak spotifyAuth, weak stravaAuth, weak reelUploadService, weak adManager] in
                        pushManager?.unregisterToken()
                        pushManager?.clearBadge()
                        spotifyAuth?.disconnect()
                        stravaAuth?.disconnect()
                        reelUploadService?.dismiss()
                        adManager?.reset()
                        ReelVideoCache.shared.clearAll()
                        OfflineActionQueue.shared.clearAll()
                        MessageCacheService.shared.clearAll()
                        UserDefaults.standard.removeObject(forKey: "music_taste_last_sync")
                        UserDefaults.standard.removeObject(forKey: "contacts_last_sync")
                        UserDefaults.standard.removeObject(forKey: "fitness_last_sync")
                        UserDefaults.standard.removeObject(forKey: "healthkit_auth_granted")
                    }
                    // Configure audio session for Bluetooth routing (calls, reels, media)
                    AudioSessionManager.shared.configure()
                    // Start periodic telemetry flush (every 5 minutes)
                    NetworkMetrics.shared.startPeriodicFlush()
                    // Register FL device and schedule background training
                    await flService.registerDevice()
                    flService.scheduleBackgroundTraining()
                    // Wire Spotify into music taste service and sync (throttled to 24h)
                    musicTasteService.setSpotifyAuth(spotifyAuth)
                    await musicTasteService.syncIfNeeded()
                    await contactMatchingService.syncIfNeeded()
                    // Wire Strava into fitness service and auto-request HealthKit + sync
                    fitnessService.setStravaAuth(stravaAuth)
                    await fitnessService.requestAuthorizationAndSync()
                    // Fetch explorer interests for profile badge
                    await mapSearchService.fetchExplorerInterests()
                    // Wire offline action queue to auto-flush when connectivity is restored
                    OfflineActionQueue.shared.observeNetwork(networkMonitor)
                    // Configure ad manager with premium status and fetch placements
                    adManager.configure(isPremium: storeKitManager.isPremium)
                    await adManager.fetchPlacements()
                    await adManager.fetchBalances()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        pushManager.clearBadge()
                        // Flush any pending offline actions when app becomes active
                        Task { await OfflineActionQueue.shared.flush() }
                        // Retry any pending chat messages queued while offline
                        Task { await flushPendingChatMessages() }
                    } else if newPhase == .background {
                        flService.scheduleBackgroundTraining()
                    }
                }
                .onChange(of: networkMonitor.isConnected) { _, connected in
                    if connected {
                        // Reset telemetry circuit breaker when connectivity is restored
                        NetworkMetrics.shared.resetCircuitBreaker()
                    }
                }
                .onChange(of: storeKitManager.isPremium) { _, isPremium in
                    adManager.updatePremiumStatus(isPremium)
                }
        }
    }
}

// MARK: - Pending Chat Flush

extension navaApp {
    /// Retries sending chat messages that were queued while offline.
    private func flushPendingChatMessages() async {
        let pending = MessageCacheService.shared.allPendingMessages()
        guard !pending.isEmpty else { return }
        NavLog.info("Flushing \(pending.count) pending chat messages", category: .network)

        for message in pending {
            do {
                let mutation = """
                mutation SendChatMessage($matchId: String!, $content: String!) {
                    sendChatMessage(matchId: $matchId, content: $content) {
                        id senderId receiverId content createdAt
                    }
                }
                """
                let _: [String: Any] = try await APIService.shared.graphQL(
                    query: mutation,
                    variables: ["matchId": message.matchId, "content": message.content]
                )
                MessageCacheService.shared.removePending(id: message.id)
            } catch {
                // Stop flushing on network error — will retry next time
                break
            }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var pushManager: PushNotificationManager

    /// Unique key that changes whenever the root screen should change,
    /// forcing SwiftUI to tear down the old NavigationStack completely.
    private var screenKey: String {
        switch auth.status {
        case .loading: return "loading"
        case .unauthenticated: return "unauth"
        case .sessionExpired: return "expired"
        case .authenticated:
            return auth.user?.isProfileComplete == true ? "main" : "onboarding"
        }
    }

    @State private var permissionsGranted = false

    var body: some View {
        ZStack {
            switch auth.status {
            case .loading:
                LoadingView()
            case .unauthenticated:
                NavigationStack {
                    LandingView()
                }
            case .sessionExpired:
                SessionExpiredView()
            case .authenticated:
                if auth.user?.isProfileComplete == true {
                    MainTabView()
                } else if permissionsGranted {
                    NavigationStack {
                        UpdateProfileView()
                    }
                } else {
                    PermissionsGateView {
                        permissionsGranted = true
                    }
                }
            }
        }
        .id(screenKey)
        .animation(.default, value: screenKey)
        .onChange(of: auth.status) { _, newStatus in
            NavLog.debug("RootView: auth.status changed to \(newStatus)", category: .auth)
            if newStatus == .authenticated {
                Task { await pushManager.requestPermission() }
            }
        }
    }
}

// MARK: - Session Expired View

struct SessionExpiredView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.purpleAccent.opacity(0.7))

            Text("Session Expired")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("Your session has ended. Please sign in again to continue where you left off.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                auth.logout()
            } label: {
                Text("Sign In Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.purpleAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.darkBg)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.purpleAccent)
            Text("Preparing your experience...")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.darkBg)
    }
}

