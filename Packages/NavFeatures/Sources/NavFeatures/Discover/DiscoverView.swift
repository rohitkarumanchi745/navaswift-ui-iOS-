import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct DiscoverView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var profiles: [DiscoverProfile] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var offset: CGSize = .zero
    @State private var showDetails = false
    @State private var selectedProfile: DiscoverProfile?
    @State private var animateOrbs = false
    @State private var errorMessage: String?
    @State private var superLikeMessage: String?
    @State private var showSuperLikeFeedback = false
    @State private var showMessageSheet = false
    @State private var messageText = ""

    #if canImport(UIKit)
    private let screenWidth = UIScreen.main.bounds.width
    #else
    private let screenWidth: CGFloat = 400
    #endif
    private var swipeThreshold: CGFloat { screenWidth * 0.25 }
    private let swipeUpThreshold: CGFloat = -120

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

                    NavigationLink(destination: ReelsView(selectedTab: .constant(0))) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }

                    NavigationLink(destination: StudentSearchView()) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }

                    NavigationLink(destination: SentLikesView()) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                    }

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

                // Offline banner
                if !networkMonitor.isConnected {
                    ErrorBanner(style: .offline)
                        .padding(.top, 4)
                }

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
                } else if let error = errorMessage {
                    // Error state
                    Spacer()
                    VStack(spacing: AppSpacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: "FF6B6B").opacity(0.7))

                        Text("Something went wrong")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xxxl)

                        Button {
                            errorMessage = nil
                            fetchProfiles()
                        } label: {
                            Text("Try Again")
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
                    // Card stack + action buttons
                    ZStack(alignment: .bottom) {
                        ZStack {
                            ForEach(Array(profiles[currentIndex..<min(currentIndex + 2, profiles.count)].enumerated().reversed()), id: \.element.id) { idx, profile in
                                let isFirst = idx == 0
                                SwipeCard(profile: profile, isFirst: isFirst, offset: isFirst ? offset : .zero, showDetails: isFirst && showDetails)
                                    .scaleEffect(isFirst ? 1.0 : 0.95)
                                    .offset(y: isFirst ? 0 : 10)
                                    .gesture(isFirst ? dragGesture : nil)
                                    .onTapGesture {
                                        if isFirst {
                                            selectedProfile = profile
                                        }
                                    }
                            }
                        }

                        // Action Buttons overlaid at bottom of card
                        HStack(spacing: 16) {
                            // Pass
                            Button { swipeLeft() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color(hex: "FF6B6B"))
                                    .frame(width: 54, height: 54)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "FF6B6B").opacity(0.12))
                                    )
                                    .overlay(
                                        Circle().stroke(Color(hex: "FF6B6B").opacity(0.35), lineWidth: 2)
                                    )
                            }

                            // Super Like
                            Button { swipeUp() } label: {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppColors.superLike)
                                    .frame(width: 46, height: 46)
                                    .background(
                                        Circle()
                                            .fill(AppColors.superLike.opacity(0.12))
                                    )
                                    .overlay(
                                        Circle().stroke(AppColors.superLike.opacity(0.35), lineWidth: 2)
                                    )
                            }

                            // Message Request
                            Button { showMessageSheet = true } label: {
                                Image(systemName: "bubble.right.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppColors.purpleAccent)
                                    .frame(width: 46, height: 46)
                                    .background(
                                        Circle()
                                            .fill(AppColors.purpleAccent.opacity(0.12))
                                    )
                                    .overlay(
                                        Circle().stroke(AppColors.purpleAccent.opacity(0.35), lineWidth: 2)
                                    )
                            }

                            // Like
                            Button { swipeRight() } label: {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color(hex: "4ECDC4"))
                                    .frame(width: 54, height: 54)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "4ECDC4").opacity(0.12))
                                    )
                                    .overlay(
                                        Circle().stroke(Color(hex: "4ECDC4").opacity(0.35), lineWidth: 2)
                                    )
                            }
                        }
                        .padding(.bottom, 18)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            fetchProfiles()
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
        .navigationDestination(item: $selectedProfile) { profile in
            MatchProfileDetailView(
                userId: profile.id,
                matchName: profile.name ?? "Unknown",
                matchPhoto: profile.primaryPhoto ?? "",
                initialProfile: profile
            )
        }
        .overlay(alignment: .top) {
            if showSuperLikeFeedback, let msg = superLikeMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.superLike.opacity(0.9))
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSuperLikeFeedback)
        .sheet(isPresented: $showMessageSheet) {
            messageRequestSheet
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                let isVerticalSwipe = abs(value.translation.height) > abs(value.translation.width)
                if isVerticalSwipe && value.translation.height < swipeUpThreshold {
                    swipeUp()
                } else if value.translation.width > swipeThreshold {
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

    private func swipeUp() {
        guard let profile = profiles[safe: currentIndex] else { return }
        withAnimation(.spring(response: 0.3)) {
            offset = CGSize(width: 0, height: -600)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleSwipe(.superlike, profile: profile)
            offset = .zero
        }
    }

    private func handleSwipe(_ action: SwipeAction, profile: DiscoverProfile) {
        currentIndex += 1
        guard !profile.id.hasPrefix("demo-") else { return }

        Task {
            do {
                if action == .superlike {
                    try await sendSuperLike(targetUserId: profile.id)
                } else if action == .like {
                    let query = """
                    mutation LikeUser($targetUserId: Int!) {
                      likeUser(targetUserId: $targetUserId) { success isMutual matchId }
                    }
                    """
                    let _: [String: Any] = try await APIService.shared.graphQL(
                        query: query,
                        variables: ["targetUserId": Int(profile.id) ?? 0]
                    )
                } else {
                    let query = "mutation PassUser($targetUserId: Int!) { passUser(targetUserId: $targetUserId) }"
                    let _: [String: Any] = try await APIService.shared.graphQL(
                        query: query,
                        variables: ["targetUserId": Int(profile.id) ?? 0]
                    )
                }
            } catch {
                NavLog.warning("Swipe action failed for \(profile.id): \(error.localizedDescription)", category: .network)
            }
        }
    }

    private func sendSuperLike(targetUserId: String) async throws {
        struct SuperLikeResponse: Decodable {
            let message: String?
            let matchId: String?
            let isMutual: Bool?
            let isSuperLike: Bool?

            enum CodingKeys: String, CodingKey {
                case message
                case matchId = "match_id"
                case isMutual = "is_mutual"
                case isSuperLike = "is_super_like"
            }
        }

        let response: SuperLikeResponse = try await APIService.shared.post(
            path: "/match/super-like",
            body: ["target_user_id": Int(targetUserId) ?? 0]
        )

        await MainActor.run {
            superLikeMessage = response.message ?? "Super Like sent!"
            showSuperLikeFeedback = true
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            showSuperLikeFeedback = false
        }
    }

    // MARK: - Message Request Sheet

    private var messageRequestSheet: some View {
        let currentProfile = profiles[safe: currentIndex]
        return NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Profile preview
                    if let profile = currentProfile {
                        HStack(spacing: 14) {
                            AsyncImage(url: AppConfig.resolvePhotoURL(profile.primaryPhoto)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure, .empty:
                                    Rectangle().fill(AppColors.darkCard)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                @unknown default:
                                    Rectangle().fill(AppColors.darkCard)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(profile.name ?? "")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                    if let age = profile.age {
                                        Text("\(age)")
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    if profile.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppColors.verified)
                                    }
                                }
                                if let location = profile.location {
                                    Text(location)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }

                    Divider()
                        .background(.white.opacity(0.1))
                        .padding(.vertical, 16)

                    // Prompt
                    Text("Send a message with your like")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Text input
                    ZStack(alignment: .topLeading) {
                        if messageText.isEmpty {
                            Text("Say something that stands out...")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $messageText)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .frame(minHeight: 120, maxHeight: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.darkCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.purpleAccent.opacity(messageText.isEmpty ? 0.15 : 0.4), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Character count
                    HStack {
                        Spacer()
                        Text("\(messageText.count)/300")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    Spacer()

                    // Send button
                    Button {
                        sendMessageRequest()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                            Text("Like with Message")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppColors.purpleAccent.opacity(0.4)
                            : AppColors.purpleAccent
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Message Request")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showMessageSheet = false
                        messageText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .toolbarBackground(AppColors.darkBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.darkBg)
    }

    private func sendMessageRequest() {
        guard let profile = profiles[safe: currentIndex] else { return }
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        showMessageSheet = false
        messageText = ""

        // Animate the card out as a like
        withAnimation(.spring(response: 0.3)) {
            offset = CGSize(width: screenWidth + 100, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            offset = .zero
        }

        // Send like + message to backend
        guard !profile.id.hasPrefix("demo-") else { return }
        Task {
            do {
                struct MessageRequestResponse: Decodable {
                    let success: Bool?
                    let matchId: String?
                    let isMutual: Bool?
                    enum CodingKeys: String, CodingKey {
                        case success
                        case matchId = "match_id"
                        case isMutual = "is_mutual"
                    }
                }
                let _: MessageRequestResponse = try await APIService.shared.post(
                    path: "/match/like",
                    body: [
                        "target_user_id": Int(profile.id) ?? 0,
                        "message": message
                    ]
                )
            } catch {
                NavLog.warning("Message request failed for \(profile.id): \(error.localizedDescription)", category: .network)
            }
        }
    }

    private func fetchProfiles() {
        isLoading = true
        errorMessage = nil
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
                    LocalCache.shared.save(profiles, forKey: .discoverFeed)
                } else {
                    profiles = []
                }
            } catch let apiError as APIError {
                NavLog.error("Discover fetch failed: \(apiError.localizedDescription)", category: .network)
                if profiles.isEmpty {
                    if let cached = LocalCache.shared.loadStale([DiscoverProfile].self, forKey: .discoverFeed) {
                        profiles = cached
                    } else {
                        errorMessage = apiError.errorDescription
                        profiles = []
                    }
                }
            } catch {
                NavLog.error("Discover fetch failed: \(error.localizedDescription)", category: .network)
                if profiles.isEmpty {
                    if let cached = LocalCache.shared.loadStale([DiscoverProfile].self, forKey: .discoverFeed) {
                        profiles = cached
                    } else {
                        errorMessage = "Could not load profiles. Please try again."
                        profiles = []
                    }
                }
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Full-bleed photo
                if let url = AppConfig.resolvePhotoURL(profile.primaryPhoto) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        case .failure:
                            photoPlaceholder(width: geo.size.width, height: geo.size.height)
                        case .empty:
                            photoPlaceholder(width: geo.size.width, height: geo.size.height)
                                .overlay {
                                    ProgressView()
                                        .tint(.white.opacity(0.6))
                                        .scaleEffect(1.2)
                                }
                        @unknown default:
                            photoPlaceholder(width: geo.size.width, height: geo.size.height)
                        }
                    }
                } else {
                    photoPlaceholder(width: geo.size.width, height: geo.size.height)
                }

                // Bottom gradient — taller for readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.3), location: 0.55),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // LIKE / NOPE / SUPER LIKE stamps
                if isFirst {
                    if offset.width > 40 {
                        Text("LIKE")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "4ECDC4"), lineWidth: 4)
                            )
                            .rotationEffect(.degrees(15))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 30)
                            .padding(.top, 50)
                    }
                    if offset.width < -40 {
                        Text("NOPE")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(Color(hex: "FF6B6B"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "FF6B6B"), lineWidth: 4)
                            )
                            .rotationEffect(.degrees(-15))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.leading, 30)
                            .padding(.top, 50)
                    }
                    if offset.height < -40 && abs(offset.height) > abs(offset.width) {
                        VStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                            Text("SUPER LIKE")
                                .font(.system(size: 28, weight: .heavy))
                        }
                        .foregroundStyle(AppColors.superLike)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(AppColors.superLike, lineWidth: 4)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }

                // Top-right badges
                VStack(alignment: .trailing, spacing: 8) {
                    if let score = profile.compatibilityScore, score > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(score)%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(AppColors.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 14)
                .padding(.top, 14)

                // Profile info at bottom
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(profile.name ?? "")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)

                        if let age = profile.age {
                            Text("\(age)")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        if profile.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppColors.verified)
                                .font(.system(size: 20))
                        }
                    }

                    if let location = profile.location, !location.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(location)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.8))
                            if let prof = profile.profession, !prof.isEmpty {
                                Text("·")
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(prof)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }

                    if let languages = profile.languages, !languages.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                            Text(languages.joined(separator: ", "))
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.white.opacity(0.55))
                    }

                    // Interests preview (first 3)
                    if let interests = profile.interests, !interests.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(interests.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if interests.count > 3 {
                                Text("+\(interests.count - 3)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 90) // room for action buttons
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .offset(x: isFirst ? offset.width : 0, y: isFirst ? offset.height : 0)
        .rotationEffect(.degrees(isFirst ? rotation : 0))
    }

    private func photoPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2A1F3D"), Color(hex: "1C1B2E"), Color(hex: "2D1B4E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width, height: height)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(.white.opacity(0.2))
                }
                Text(profile.name ?? "")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}
