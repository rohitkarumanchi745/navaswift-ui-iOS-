import SwiftUI
import NavCore
import NavNetworking

struct SentLikesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sentLikes: [SentLikeProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(hex: "1A1B2E"),
                    Color(hex: "2D1B4E"),
                    Color(hex: "1A1B2E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sent Likes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(sentLikes.count) profiles you liked")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color(hex: "C9A0DC"))
                            Text("Loading...")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await fetchSentLikes() } }
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(hex: "C9A0DC"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
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
                        .padding(.top, 80)
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

                        // Regular likes section
                        if !regularLikes.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "C9A0DC"))
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
            .refreshable { await fetchSentLikes() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .task { await fetchSentLikes() }
    }

    // MARK: - Fetch

    private func fetchSentLikes() async {
        isLoading = sentLikes.isEmpty
        errorMessage = nil
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

// MARK: - Model

struct SentLikeProfile: Identifiable, Codable {
    let id: String
    let name: String
    let age: Int
    let photo: String
    let isSuperLike: Bool
    let likedAt: String

}

// MARK: - Card

struct SentLikeCard: View {
    let profile: SentLikeProfile

    var body: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(hex: "2D3047"))
            }
            .frame(height: 220)
            .clipped()

            // Gradient overlay with info
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

            // Badge — star for super like, heart for regular
            Circle()
                .fill(profile.isSuperLike ? AppColors.superLike : Color(hex: "C9A0DC"))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: profile.isSuperLike ? "star.fill" : "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            profile.isSuperLike
                ? RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.superLike.opacity(0.5), lineWidth: 2)
                : nil
        )
    }
}
