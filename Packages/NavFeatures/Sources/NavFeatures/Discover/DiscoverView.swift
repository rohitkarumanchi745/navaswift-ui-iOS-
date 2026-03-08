import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct DiscoverView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var profiles: [DiscoverProfile] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var offset: CGSize = .zero
    @State private var showDetails = false
    @State private var animateOrbs = false

    #if canImport(UIKit)
    private let screenWidth = UIScreen.main.bounds.width
    #else
    private let screenWidth: CGFloat = 400
    #endif
    private var swipeThreshold: CGFloat { screenWidth * 0.25 }

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

            // Floating orbs
            Circle()
                .fill(Color(hex: "9B7FCA").opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: -100, y: animateOrbs ? -200 : -160)

            Circle()
                .fill(Color(hex: "A8D8EA").opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: 120, y: animateOrbs ? 300 : 260)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("NAVA")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color(hex: "C9A0DC"))
                        .tracking(2)

                    Spacer()

                    NavigationLink(destination: PreferencesView()) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)

                if isLoading {
                    Spacer()
                    VStack(spacing: AppSpacing.lg) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(hex: "C9A0DC"))
                        Text("Finding people for you...")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                } else if currentIndex >= profiles.count {
                    // Empty state
                    Spacer()
                    VStack(spacing: AppSpacing.xl) {
                        Circle()
                            .fill(Color(hex: "9B7FCA").opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "heart")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color(hex: "C9A0DC"))
                            }

                        Text("No more profiles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text("Check back later for new people in your area")
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)

                        Button {
                            fetchProfiles()
                        } label: {
                            Text("Refresh")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.xxxl)
                                .padding(.vertical, AppSpacing.md)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
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
                            ActionCircleButton(icon: "arrow.uturn.backward", size: 44, color: Color(hex: "D4A5C9")) {}
                            ActionCircleButton(icon: "xmark", size: 60, color: Color(hex: "B0B0B0"), borderColor: Color(hex: "B0B0B0")) {
                                swipeLeft()
                            }
                            ActionCircleButton(icon: "star.fill", size: 52, color: Color(hex: "A8D8EA"), borderColor: Color(hex: "A8D8EA")) {
                                handleSwipe(.superlike, profile: profile)
                            }
                            ActionCircleButton(icon: "heart.fill", size: 60, color: Color(hex: "98D4BB"), borderColor: Color(hex: "98D4BB")) {
                                swipeRight()
                            }
                            ActionCircleButton(icon: "bolt.fill", size: 44, color: Color(hex: "D4C5A0")) {}
                        }
                        .padding(.vertical, AppSpacing.xl)
                    }
                }
            }
        }
        .onAppear {
            fetchProfiles()
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
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
                if let url = AppConfig.resolvePhotoURL(profile.primaryPhoto) {
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
                                .foregroundStyle(Color(hex: "D4C5A0"))
                            Text("\(score)% Match")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: "D4C5A0"))
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
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                            Text(bio)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                    }
                    if let interests = profile.interests, !interests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interests")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                            FlowLayout(spacing: 8) {
                                ForEach(interests, id: \.self) { interest in
                                    Text(interest)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: "C9A0DC"))
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                        .background(Color(hex: "C9A0DC").opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxHeight: 200)
                .background(Color(hex: "1A1B2E"))
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
                .background(.white.opacity(0.1))
                .clipShape(Circle())
                .overlay {
                    if let border = borderColor {
                        Circle().strokeBorder(border.opacity(0.5), lineWidth: 2)
                    } else {
                        Circle().stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                }
        }
    }
}
