import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct MatchesView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var likedProfiles: [LikedProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Likes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(likedProfiles.count) people liked you")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if !storeKit.isPremium {
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
                    let superLiked = likedProfiles.filter { $0.type == .superLike }
                    let regularLikes = likedProfiles.filter { $0.type != .superLike }

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
                    if !regularLikes.isEmpty && !superLiked.isEmpty {
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
        }
        .background(AppColors.darkBg)
        .navigationBarHidden(true)
        .task {
            await fetchLikes()
        }
        .refreshable { await fetchLikes() }
    }

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
                        likedAt: formatTimestamp(m["matchedAt"] as? String) ?? ""
                    )
                }
                likedProfiles = fetched.isEmpty ? LikedProfile.demos : fetched
            } else {
                likedProfiles = LikedProfile.demos
            }
        } catch {
            if likedProfiles.isEmpty {
                likedProfiles = LikedProfile.demos
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
}

struct LikedProfileCard: View {
    let profile: LikedProfile
    let isPremium: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo
            AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(AppColors.darkCard)
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
