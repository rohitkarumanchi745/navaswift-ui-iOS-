import SwiftUI

@main
struct navaApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(storeKitManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        Group {
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
        .animation(.easeInOut, value: auth.status)
        .onChange(of: auth.status) { _, newStatus in
            if newStatus == .authenticated {
                // Request location permission and send to backend after login
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
