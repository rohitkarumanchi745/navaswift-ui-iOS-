import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var profiles: [DiscoverProfile] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var offset: CGSize = .zero
    @State private var showDetails = false

    #if canImport(UIKit)
    private let screenWidth = UIScreen.main.bounds.width
    #else
    private let screenWidth: CGFloat = 400
    #endif
    private var swipeThreshold: CGFloat { screenWidth * 0.25 }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("NAVA")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(AppColors.primary)
                    .tracking(2)

                Spacer()

                NavigationLink(destination: PreferencesView()) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)

            if isLoading {
                Spacer()
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColors.primary)
                    Text("Finding people for you...")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if currentIndex >= profiles.count {
                // Empty state
                Spacer()
                VStack(spacing: AppSpacing.xl) {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "heart")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColors.primary)
                        }

                    Text("No more profiles")
                        .font(.system(size: 24, weight: .bold))

                    Text("Check back later for new people in your area")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        fetchProfiles()
                    } label: {
                        Text("Refresh")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xxxl)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.brandGradient)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, AppSpacing.xxxl)
                Spacer()
            } else {
                // Card stack
                ZStack {
                    ForEach(Array(profiles[currentIndex..<min(currentIndex + 2, profiles.count)].enumerated().reversed()), id: \.element.id) { idx, profile in
                        let isFirst = idx == 0
                        SwipeCard(profile: profile, isFirst: isFirst, offset: isFirst ? offset : .zero, showDetails: isFirst && showDetails)
                            .scaleEffect(isFirst ? 1.0 : 0.95)
                            .offset(y: isFirst ? 0 : 10)
                            .gesture(isFirst ? dragGesture : nil)
                            .onTapGesture {
                                if isFirst { showDetails.toggle() }
                            }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                // Action Buttons
                if let profile = profiles[safe: currentIndex] {
                    HStack(spacing: AppSpacing.md) {
                        ActionCircleButton(icon: "arrow.uturn.backward", size: 44, color: AppColors.rewind) {}
                        ActionCircleButton(icon: "xmark", size: 60, color: AppColors.pass, borderColor: AppColors.pass) {
                            swipeLeft()
                        }
                        ActionCircleButton(icon: "star.fill", size: 52, color: AppColors.superLike, borderColor: AppColors.superLike) {
                            handleSwipe(.superlike, profile: profile)
                        }
                        ActionCircleButton(icon: "heart.fill", size: 60, color: AppColors.like, borderColor: AppColors.like) {
                            swipeRight()
                        }
                        ActionCircleButton(icon: "bolt.fill", size: 44, color: AppColors.boost) {}
                    }
                    .padding(.vertical, AppSpacing.xl)
                }
            }
        }
        .background(Color(.systemGray6))
        .onAppear { fetchProfiles() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    swipeRight()
                } else if value.translation.width < -swipeThreshold {
                    swipeLeft()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        offset = .zero
                    }
                }
            }
    }

    private func swipeRight() {
        guard let profile = profiles[safe: currentIndex] else { return }
        withAnimation(.spring(response: 0.3)) {
            offset = CGSize(width: screenWidth + 100, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleSwipe(.like, profile: profile)
            offset = .zero
        }
    }

    private func swipeLeft() {
        guard let profile = profiles[safe: currentIndex] else { return }
        withAnimation(.spring(response: 0.3)) {
            offset = CGSize(width: -screenWidth - 100, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleSwipe(.pass, profile: profile)
            offset = .zero
        }
    }

    private func handleSwipe(_ action: SwipeAction, profile: DiscoverProfile) {
        currentIndex += 1
        guard !profile.id.hasPrefix("demo-") else { return }

        Task {
            if action == .like || action == .superlike {
                let query = """
                mutation LikeUser($targetUserId: Int!) {
                  likeUser(targetUserId: $targetUserId) { success isMutual matchId }
                }
                """
                let _: [String: Any]? = try? await APIService.shared.graphQL(
                    query: query,
                    variables: ["targetUserId": Int(profile.id) ?? 0]
                )
            } else {
                let query = "mutation PassUser($targetUserId: Int!) { passUser(targetUserId: $targetUserId) }"
                let _: [String: Any]? = try? await APIService.shared.graphQL(
                    query: query,
                    variables: ["targetUserId": Int(profile.id) ?? 0]
                )
            }
        }
    }

    private func fetchProfiles() {
        isLoading = true
        Task {
            do {
                let query = """
                query Discover($filters: DiscoverFilters) {
                  discover(filters: $filters) {
                    id name age bio location photos interests languages
                    compatibilityScore isVerified professionTitle voiceIntroUrl hasVoiceIntro
                  }
                }
                """
                let result: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: ["filters": ["useAi": true, "limit": 20]]
                )

                if let discover = result["discover"] as? [[String: Any]], !discover.isEmpty {
                    profiles = discover.map { p in
                        DiscoverProfile(
                            id: "\(p["id"] ?? "")",
                            name: p["name"] as? String,
                            age: p["age"] as? Int,
                            location: p["location"] as? String,
                            profession: p["professionTitle"] as? String,
                            compatibilityScore: (p["compatibilityScore"] as? Double).map { Int($0) },
                            bio: p["bio"] as? String,
                            interests: p["interests"] as? [String],
                            photos: p["photos"] as? [String],
                            isVerified: p["isVerified"] as? Bool ?? false,
                            voiceIntroUrl: p["voiceIntroUrl"] as? String,
                            hasVoiceIntro: p["hasVoiceIntro"] as? Bool ?? false,
                            hasReels: false,
                            languages: p["languages"] as? [String]
                        )
                    }
                } else {
                    profiles = DiscoverProfile.demos
                }
            } catch {
                profiles = DiscoverProfile.demos
            }
            currentIndex = 0
            isLoading = false
        }
    }
}

enum SwipeAction { case like, pass, superlike }

// MARK: - Swipe Card
struct SwipeCard: View {
    let profile: DiscoverProfile
    let isFirst: Bool
    let offset: CGSize
    let showDetails: Bool

    private var rotation: Double {
        Double(offset.width / 20)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Photo
                if let photoURL = profile.primaryPhoto, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                            .overlay { ProgressView() }
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // LIKE / NOPE stamps
                if isFirst {
                    if offset.width > 40 {
                        Text("LIKE")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(AppColors.like)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(AppColors.like, lineWidth: 4)
                            )
                            .rotationEffect(.degrees(15))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 30)
                            .padding(.top, 50)
                    }
                    if offset.width < -40 {
                        Text("NOPE")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(AppColors.error)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(AppColors.error, lineWidth: 4)
                            )
                            .rotationEffect(.degrees(-15))
                            .position(x: 80, y: 80)
                    }
                }

                // Top badges
                VStack(alignment: .trailing, spacing: 8) {
                    if profile.hasReels {
                        HStack(spacing: 4) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 12))
                            Text("Reels")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    if let score = profile.compatibilityScore {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.gold)
                            Text("\(score)% Match")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.gold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, AppSpacing.md)
                .padding(.top, AppSpacing.xxl)

                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.name ?? "")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        if let age = profile.age {
                            Text("\(age)")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        }

                        if profile.isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.verified)
                                .font(.system(size: 22))
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.system(size: 14))
                        Text(profile.location ?? "")
                            .font(.system(size: 15))
                        if let prof = profile.profession {
                            Text("  \(prof)")
                                .font(.system(size: 15))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.9))

                    if let languages = profile.languages, !languages.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                            Text(languages.joined(separator: ", "))
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
            }
            .clipped()

            // Expanded details
            if showDetails {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let bio = profile.bio {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(bio)
                                .font(.system(size: 16))
                                .lineSpacing(4)
                        }
                    }
                    if let interests = profile.interests, !interests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interests")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            FlowLayout(spacing: 8) {
                                ForEach(interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppColors.primary)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                        .background(AppColors.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxHeight: 200)
                .background(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .offset(x: isFirst ? offset.width : 0, y: isFirst ? offset.height : 0)
        .rotationEffect(.degrees(isFirst ? rotation : 0))
    }
}

// MARK: - Action Circle Button
struct ActionCircleButton: View {
    let icon: String
    let size: CGFloat
    let color: Color
    var borderColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.35))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(.white)
                .clipShape(Circle())
                .overlay {
                    if let border = borderColor {
                        Circle().strokeBorder(border, lineWidth: 2)
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ), proposal: .unspecified)
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
