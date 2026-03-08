import SwiftUI
import NavCore
import NavServices
import NavFeatures

@main
struct navaApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var callManager = CallManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(storeKitManager)
                .environmentObject(callManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager

    /// Unique key that changes whenever the root screen should change,
    /// forcing SwiftUI to tear down the old NavigationStack completely.
    private var screenKey: String {
        switch auth.status {
        case .loading: return "loading"
        case .unauthenticated: return "unauth"
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
            print("[NAVA DEBUG] RootView: auth.status changed to \(newStatus)")
            if newStatus == .authenticated {
                locationManager.requestPermission()
                locationManager.updateLocation()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)
            Text("Preparing your experience...")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.warmWhite)
    }
}
