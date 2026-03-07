import SwiftUI
import NavCore
import NavNetworking
import NavServices

public struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
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
                MatchesView()
            }
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Likes")
            }
            .badge(likesCount)
            .tag(1)

            NavigationStack {
                ConversationsView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat")
            }
            .badge(unreadChats)
            .tag(2)

            NavigationStack {
                ReelsView()
            }
            .tabItem {
                Image(systemName: "play.rectangle.fill")
                Text("Reels")
            }
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
        .tint(AppColors.primary)
        .task { await fetchBadgeCounts() }
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 { likesCount = 0 }
            if tab == 2 { unreadChats = 0 }
        }
    }

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
        } catch {}
    }
}
