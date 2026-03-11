import SwiftUI
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

    init() {
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
                .task {
                    // Connect AppDelegate to PushNotificationManager
                    appDelegate.pushManager = pushManager
                    // Start periodic telemetry flush (every 5 minutes)
                    NetworkMetrics.shared.startPeriodicFlush()
                }
                .onChange(of: networkMonitor.isConnected) { _, connected in
                    if connected {
                        // Reset telemetry circuit breaker when connectivity is restored
                        NetworkMetrics.shared.resetCircuitBreaker()
                    }
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
                } else {
                    NavigationStack {
                        UpdateProfileView()
                    }
                }
            }
        }
        .id(screenKey)
        .animation(.default, value: screenKey)
        .onChange(of: auth.status) { _, newStatus in
            NavLog.debug("RootView: auth.status changed to \(newStatus)", category: .auth)
            if newStatus == .authenticated {
                locationManager.requestPermission()
                locationManager.updateLocation()
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

