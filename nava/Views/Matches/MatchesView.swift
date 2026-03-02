import SwiftUI

struct MatchesView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var likedProfiles = LikedProfile.demos
    @State private var isPremium = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Likes")
                            .font(.system(size: 28, weight: .bold))
                        Text("\(likedProfiles.count) people liked you")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isPremium {
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

                // Grid of liked profiles
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(likedProfiles) { profile in
                        LikedProfileCard(profile: profile, isPremium: isPremium)
                    }

                    // Unlock card
                    if !isPremium {
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
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

struct LikedProfileCard: View {
    let profile: LikedProfile
    let isPremium: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo
            AsyncImage(url: URL(string: profile.photo)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
            .frame(height: 200)
            .clipped()

            // Gradient and info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.name), \(profile.age)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(profile.likedAt) ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
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

            // Like indicator
            Circle()
                .fill(AppColors.primary)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
