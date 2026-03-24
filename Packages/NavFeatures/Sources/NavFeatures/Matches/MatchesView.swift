import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct MatchesView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var likedProfiles: [LikedProfile] = []
    @State private var sentLikes: [SentLikeProfile] = []
    @State private var isLoading = true
    @State private var isSentLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab: LikesTab = .likedYou

    enum LikesTab: String, CaseIterable {
        case likedYou = "Liked You"
        case youLiked = "You Liked"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Likes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text(headerSubtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if !storeKit.isPremium && selectedTab == .likedYou {
                        NavigationLink(destination: PremiumView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(AppColors.gold)
                                Text("Unlock")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.gold.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Tab toggle
                tabToggle
                    .padding(.horizontal, 20)

                // Content
                if selectedTab == .likedYou {
                    likedYouContent
                } else {
                    youLikedContent
                }
            }
        }
        .background(AppColors.darkBg)
        .navigationBarHidden(true)
        .task {
            await fetchLikes()
            await fetchSentLikes()
        }
        .refreshable {
            if selectedTab == .likedYou {
                await fetchLikes()
            } else {
                await fetchSentLikes()
            }
        }
    }

    private var headerSubtitle: String {
        switch selectedTab {
        case .likedYou:
            return "\(likedProfiles.count) people liked you"
        case .youLiked:
            return "\(sentLikes.count) profiles you liked"
        }
    }

    // MARK: - Tab Toggle

    private var tabToggle: some View {
        HStack(spacing: 0) {
            ForEach(LikesTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? AppColors.purpleAccent.opacity(0.25)
                                : Color.clear
                        )
                }
            }
        }
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Liked You Content

    private var likedYouContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(AppColors.purpleAccent)
                    Text("Loading likes...")
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
                    Button("Retry") { Task { await fetchLikes() } }
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColors.purpleAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if likedProfiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No likes yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Keep swiping and complete your profile to attract more people!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                let withMessages = likedProfiles.filter { $0.message != nil }
                let withoutMessages = likedProfiles.filter { $0.message == nil }
                let superLiked = withoutMessages.filter { $0.type == .superLike }
                let regularLikes = withoutMessages.filter { $0.type != .superLike }

                // Message Requests section
                if !withMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.purpleAccent)
                            Text("Message Requests")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Text("(\(withMessages.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(withMessages) { profile in
                                    NavigationLink(destination: MessageRequestDetailView(
                                        profile: profile,
                                        isPremium: storeKit.isPremium,
                                        onAccept: { _ in
                                            withAnimation {
                                                likedProfiles.removeAll { $0.id == profile.id }
                                            }
                                        },
                                        onDecline: {
                                            withAnimation {
                                                likedProfiles.removeAll { $0.id == profile.id }
                                            }
                                        }
                                    )) {
                                        MessageRequestCard(profile: profile, isPremium: storeKit.isPremium)
                                            .frame(width: 220)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Super Liked You section
                if !superLiked.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.superLike)
                            Text("Super Liked You")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Text("(\(superLiked.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(superLiked) { profile in
                                    LikedProfileCard(profile: profile, isPremium: storeKit.isPremium)
                                        .frame(width: 160, height: 200)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Regular likes header
                if !regularLikes.isEmpty && (!superLiked.isEmpty || !withMessages.isEmpty) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.primary)
                        Text("Liked You")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(regularLikes.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                }

                // Grid of liked profiles
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(regularLikes) { profile in
                        LikedProfileCard(profile: profile, isPremium: storeKit.isPremium)
                    }

                    // Unlock card
                    if !storeKit.isPremium {
                        NavigationLink(destination: PremiumView()) {
                            VStack(spacing: 8) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                                Text("See who\nlikes you")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.gradientMiddle],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - You Liked Content

    private var youLikedContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isSentLoading {
                VStack {
                    ProgressView()
                        .tint(AppColors.purpleAccent)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if sentLikes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No likes yet")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Swipe right on profiles you're interested in and they'll show up here!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                let superLiked = sentLikes.filter { $0.isSuperLike }
                let regularLikes = sentLikes.filter { !$0.isSuperLike }

                // Super Liked section
                if !superLiked.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.superLike)
                            Text("Super Liked")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Text("(\(superLiked.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(superLiked) { profile in
                                    NavigationLink(destination: MatchProfileDetailView(
                                        userId: profile.id,
                                        matchName: profile.name,
                                        matchPhoto: profile.photo
                                    )) {
                                        SentLikeCard(profile: profile)
                                            .frame(width: 160)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Regular likes header
                if !regularLikes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text("Liked")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(regularLikes.count))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(regularLikes) { profile in
                        NavigationLink(destination: MatchProfileDetailView(
                            userId: profile.id,
                            matchName: profile.name,
                            matchPhoto: profile.photo
                        )) {
                            SentLikeCard(profile: profile)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Fetch Likes (who liked you)

    private func fetchLikes() async {
        isLoading = likedProfiles.isEmpty
        errorMessage = nil
        do {
            let query = """
            query {
                matches {
                    id
                    partner {
                        id name age photos
                    }
                    isMutual
                    likeType
                    message
                    matchedAt
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let matchList = result["matches"] as? [[String: Any]] {
                let fetched = matchList.compactMap { m -> LikedProfile? in
                    guard let partner = m["partner"] as? [String: Any],
                          let isMutual = m["isMutual"] as? Bool, !isMutual else { return nil }
                    let photos = partner["photos"] as? [String]
                    let likeTypeStr = m["likeType"] as? String ?? "swipe"
                    let likeType = LikedProfile.LikeType(rawValue: likeTypeStr) ?? .swipe
                    return LikedProfile(
                        id: "\(partner["id"] ?? "")",
                        name: partner["name"] as? String ?? "Unknown",
                        age: partner["age"] as? Int ?? 0,
                        photo: photos?.first ?? "",
                        type: likeType,
                        likedAt: formatTimestamp(m["matchedAt"] as? String) ?? "",
                        message: m["message"] as? String
                    )
                }
                likedProfiles = fetched
            } else {
                likedProfiles = []
            }
        } catch {
            if likedProfiles.isEmpty {
                likedProfiles = []
            }
        }
        isLoading = false
    }

    // MARK: - Fetch Sent Likes (you liked)

    private func fetchSentLikes() async {
        isSentLoading = sentLikes.isEmpty
        do {
            let query = """
            query {
                sentLikes {
                    id name age photo likeType likedAt
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let likeList = result["sentLikes"] as? [[String: Any]] {
                let fetched = likeList.compactMap { item -> SentLikeProfile? in
                    guard let id = item["id"] as? String else { return nil }
                    let likeType = item["likeType"] as? String ?? "swipe"
                    return SentLikeProfile(
                        id: id,
                        name: item["name"] as? String ?? "Unknown",
                        age: item["age"] as? Int ?? 0,
                        photo: item["photo"] as? String ?? "",
                        isSuperLike: likeType == "super_like",
                        likedAt: formatTimestamp(item["likedAt"] as? String) ?? ""
                    )
                }
                sentLikes = fetched
            } else {
                sentLikes = []
            }
        } catch {
            if sentLikes.isEmpty {
                sentLikes = []
            }
        }
        isSentLoading = false
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
}

struct LikedProfileCard: View {
    let profile: LikedProfile
    let isPremium: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo
            AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(AppColors.darkCard)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppColors.purpleAccent.opacity(0.4))
                        }
                case .empty:
                    Rectangle().fill(AppColors.darkCard)
                        .overlay { ProgressView().tint(AppColors.purpleAccent) }
                @unknown default:
                    Rectangle().fill(AppColors.darkCard)
                }
            }
            .frame(height: 200)
            .clipped()

            // Gradient and info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.name), \(profile.age)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if !profile.likedAt.isEmpty {
                    Text("\(profile.likedAt) ago")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Blur overlay for non-premium
            if !isPremium {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }

            // Like indicator — star for super like, heart for regular
            Circle()
                .fill(profile.type == .superLike ? AppColors.superLike : AppColors.primary)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: profile.type == .superLike ? "star.fill" : "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            profile.type == .superLike
                ? RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.superLike.opacity(0.5), lineWidth: 2)
                : nil
        )
    }
}

// MARK: - Message Request Card

struct MessageRequestCard: View {
    let profile: LikedProfile
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo section
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle().fill(AppColors.darkCard)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppColors.purpleAccent.opacity(0.4))
                            }
                    case .empty:
                        Rectangle().fill(AppColors.darkCard)
                            .overlay { ProgressView().tint(AppColors.purpleAccent) }
                    @unknown default:
                        Rectangle().fill(AppColors.darkCard)
                    }
                }
                .frame(height: 140)
                .clipped()

                // Blur overlay for non-premium
                if !isPremium {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 140)
                }

                // Like type badge
                Circle()
                    .fill(profile.type == .superLike ? AppColors.superLike : AppColors.purpleAccent)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: profile.type == .superLike ? "star.fill" : "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .padding(8)
            }

            // Info + message section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(profile.name), \(profile.age)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(profile.likedAt)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if let message = profile.message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(AppColors.darkCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.purpleAccent.opacity(0.3), lineWidth: 1)
        )
    }
}
