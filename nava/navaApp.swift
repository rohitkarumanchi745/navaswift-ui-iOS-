import SwiftUI

@main
struct navaApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthManager

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
