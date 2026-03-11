import SwiftUI
import NavCore
import NavNetworking
import NavServices

public struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab = 0
    @State private var likesCount = 0
    @State private var unreadChats = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Image(systemName: "flame.fill")
                Text("Discover")
            }
            .tag(0)

            NavigationStack {
                StudentSearchView()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(1)

            NavigationStack {
                MatchesView()
            }
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Likes")
            }
            .badge(likesCount)
            .tag(2)

            NavigationStack {
                ConversationsView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat")
            }
            .badge(unreadChats)
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
            .tag(4)
        }
        .overlay {
            if pushManager.isPrefetchingDeepLink {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading content…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.25), value: pushManager.isPrefetchingDeepLink)
            }
        }
        .tint(AppColors.purpleAccent)
        .task { await fetchBadgeCounts() }
        .onChange(of: selectedTab) { _, tab in
            if tab == 2 { likesCount = 0 }
            if tab == 3 { unreadChats = 0 }
        }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if connected {
                Task { await fetchBadgeCounts() }
            }
        }
        .onChange(of: pushManager.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            handleDeepLink(deepLink)
            pushManager.pendingDeepLink = nil
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ deepLink: DeepLink) {
        NavLog.debug("MainTabView handling deep link: \(deepLink)", category: .general)
        selectedTab = deepLink.tabIndex
    }

    // MARK: - Badge Counts

    private func fetchBadgeCounts() async {
        do {
            let query = """
            query {
                matches {
                    id
                    isMutual
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let matchList = result["matches"] as? [[String: Any]] {
                let nonMutual = matchList.filter { ($0["isMutual"] as? Bool) == false }
                let mutual = matchList.filter { ($0["isMutual"] as? Bool) == true }
                likesCount = nonMutual.count
                unreadChats = mutual.count > 0 ? mutual.count : 0
            }
        } catch {
            NavLog.debug("Badge count fetch failed: \(error.localizedDescription)", category: .network)
        }
    }
}
