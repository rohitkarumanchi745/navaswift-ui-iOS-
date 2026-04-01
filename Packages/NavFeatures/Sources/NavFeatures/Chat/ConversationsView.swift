import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct ConversationsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var adManager: AdManager
    @State private var conversations: [MatchProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Messages")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    if totalUnread > 0 {
                        Text("\(totalUnread) new")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)

                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.purpleAccent)
                        Text("Loading conversations...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await fetchConversations() } }
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColors.purpleAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("When you match with someone, you can start chatting here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // Online matches (horizontal scroll)
                    let onlineMatches = conversations.filter(\.isOnline)
                    if !onlineMatches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(onlineMatches) { match in
                                    NavigationLink(destination: ChatView(match: match)) {
                                        VStack(spacing: 6) {
                                            ZStack(alignment: .bottomTrailing) {
                                                AsyncImage(url: AppConfig.resolvePhotoURL(match.photo)) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    Circle().fill(AppColors.darkCard)
                                                }
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())

                                                Circle()
                                                    .fill(AppColors.online)
                                                    .frame(width: 14, height: 14)
                                                    .overlay {
                                                        Circle().strokeBorder(.white, lineWidth: 2)
                                                    }
                                            }
                                            Text(match.name)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        AppColors.darkDivider.frame(height: 1).padding(.horizontal, 20)
                    }

                    // Message list
                    VStack(spacing: 0) {
                        ForEach(conversations) { match in
                            NavigationLink(destination: ChatView(match: match)) {
                                HStack(spacing: 12) {
                                    ZStack(alignment: .bottomTrailing) {
                                        AsyncImage(url: AppConfig.resolvePhotoURL(match.photo)) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(AppColors.darkCard)
                                        }
                                        .frame(width: 52, height: 52)
                                        .clipShape(Circle())

                                        if match.isOnline {
                                            Circle()
                                                .fill(AppColors.online)
                                                .frame(width: 14, height: 14)
                                                .overlay {
                                                    Circle().strokeBorder(AppColors.darkBg, lineWidth: 2)
                                                }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(match.name)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(match.timestamp ?? "")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        Text(match.lastMessage ?? "Say hi!")
                                            .font(.system(size: 14))
                                            .foregroundStyle(match.unreadCount > 0 ? .white : .white.opacity(0.5))
                                            .fontWeight(match.unreadCount > 0 ? .medium : .regular)
                                            .lineLimit(1)
                                    }

                                    if match.unreadCount > 0 {
                                        Text("\(match.unreadCount)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 24, minHeight: 24)
                                            .background(AppColors.primary)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppColors.darkCard)
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BannerAdView(placementId: AdManager.PlacementID.chatBanner)
        }
        .background(AppColors.darkBg)
        .navigationBarHidden(true)
        .task {
            // Show cached conversation list instantly
            if let cached = LocalCache.shared.loadStale([MatchProfile].self, forKey: .conversations), !cached.isEmpty {
                conversations = cached
                isLoading = false
            }
            await fetchConversations()
        }
        .refreshable { await fetchConversations() }
    }

    private func fetchConversations() async {
        isLoading = conversations.isEmpty
        errorMessage = nil
        do {
            let query = """
            query {
                matches {
                    id
                    partner {
                        id name age photos isOnline lastSeen
                    }
                    isMutual
                    matchedAt
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let matchList = result["matches"] as? [[String: Any]] {
                let fetched = matchList.compactMap { m -> MatchProfile? in
                    guard let partner = m["partner"] as? [String: Any],
                          let isMutual = m["isMutual"] as? Bool, isMutual else { return nil }
                    let photos = partner["photos"] as? [String]
                    let online = partner["isOnline"] as? Bool ?? false
                    let lastSeenDate = Self.parseISO(partner["lastSeen"] as? String)
                    return MatchProfile(
                        id: "\(partner["id"] ?? "")",
                        matchId: "\(m["id"] ?? "")",
                        name: partner["name"] as? String ?? "Unknown",
                        age: partner["age"] as? Int ?? 0,
                        photo: photos?.first ?? "",
                        lastMessage: nil,
                        timestamp: formatTimestamp(m["matchedAt"] as? String),
                        unreadCount: 0,
                        isOnline: online,
                        isMutual: true,
                        lastSeen: lastSeenDate
                    )
                }
                conversations = fetched
                if !fetched.isEmpty {
                    LocalCache.shared.save(fetched, forKey: .conversations)
                }
            } else {
                conversations = []
            }
        } catch {
            if conversations.isEmpty {
                if let cached = LocalCache.shared.loadStale([MatchProfile].self, forKey: .conversations) {
                    conversations = cached
                    errorMessage = nil
                } else {
                    errorMessage = "Could not load conversations."
                    conversations = []
                }
            }
        }
        isLoading = false
    }

    private func formatTimestamp(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return nil }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    private static func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
