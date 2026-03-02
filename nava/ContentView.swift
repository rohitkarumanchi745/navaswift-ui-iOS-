import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var selectedTab = 0

    var body: some View {
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
            .tag(1)

            NavigationStack {
                ConversationsView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chat")
            }
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
    }
}
