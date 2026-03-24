import SwiftUI
import AVKit
import NavCore
import NavNetworking
import NavServices

// MARK: - Full dating profile shown when tapping a match's avatar in chat

struct MatchProfileDetailView: View {
    let userId: String
    let matchName: String
    let matchPhoto: String
    var initialProfile: DiscoverProfile? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var profile: DiscoverProfile?
    @State private var reels: [Reel] = []
    @State private var isLoading = true
    @State private var showReelFeed = false
    @State private var tappedReelIndex = 0

    private var photos: [String] {
        let p = profile?.photos ?? [matchPhoto]
        return p.isEmpty ? [matchPhoto] : p
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if isLoading {
                        Rectangle().fill(AppColors.darkCard)
                            .frame(height: 500)
                            .overlay { ProgressView().tint(AppColors.purpleAccent) }
                    } else {
                        interleavedContent
                    }

                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.darkBg)
            .ignoresSafeArea(edges: .top)

            // Back button
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 56)
        }
        .navigationBarHidden(true)
        .task {
            if let initial = initialProfile {
                profile = initial
                isLoading = false
            } else {
                await fetchProfile()
            }
            await fetchReels()
        }
        .fullScreenCover(isPresented: $showReelFeed) {
            ProfileReelFeedView(
                initialReels: reels,
                startIndex: tappedReelIndex,
                userName: profile?.name ?? matchName
            )
        }
    }

    // MARK: - Interleaved Content

    @ViewBuilder
    private var interleavedContent: some View {
        // Photo 1 (hero) + Name overlay
        heroPhoto

        // Profile info bar
        profileInfo
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

        // Voice intro
        if profile?.hasVoiceIntro == true, let voiceUrl = profile?.voiceIntroUrl, !voiceUrl.isEmpty {
            VoiceIntroPlayer(url: voiceUrl)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }

        // Bio section
        if let bio = profile?.bio, !bio.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("About")
                    Text(bio)
                        .font(.system(size: 16))
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }

        // Photo 2
        if photos.count > 1 {
            profilePhoto(photos[1])
                .padding(.top, 16)
        }

        // Interests
        if let interests = profile?.interests, !interests.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Interests")
                    FlowLayout(spacing: 8) {
                        ForEach(interests, id: \.self) { interest in
                            Text(interest)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.purpleAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppColors.purpleAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }

        // Photo 3
        if photos.count > 2 {
            profilePhoto(photos[2])
                .padding(.top, 16)
        }

        // Languages
        if let languages = profile?.languages, !languages.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Languages")
                    HStack(spacing: 8) {
                        ForEach(languages, id: \.self) { lang in
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.superLike)
                                Text(lang)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppColors.superLike.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }

        // Photo 4+
        ForEach(Array(photos.dropFirst(3).enumerated()), id: \.offset) { _, photo in
            profilePhoto(photo)
                .padding(.top, 16)
        }

        // Reels
        if !reels.isEmpty {
            reelsSection
                .padding(.top, 20)
        }
    }

    // MARK: - Hero Photo (first photo with name overlay)

    private var heroPhoto: some View {
        ZStack(alignment: .bottom) {
            profilePhotoImage(photos[0])
                .frame(height: 520)
                .clipped()

            // Gradient
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: .black.opacity(0.7), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Name + age
            HStack(spacing: 10) {
                Text(profile?.name ?? matchName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                if let age = profile?.age {
                    Text("\(age)")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                }

                if profile?.isVerified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.verified)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Match score badge top-right
            if let score = profile?.compatibilityScore, score > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(score)% Match")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 16)
                .padding(.top, 56)
            }
        }
    }

    // MARK: - Profile Info

    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let location = profile?.location, !location.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.purpleAccent)
                    Text(location)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if let profession = profile?.profession, !profession.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.purpleAccent)
                    Text(profession)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Photo Components

    private func profilePhoto(_ photo: String) -> some View {
        profilePhotoImage(photo)
            .frame(maxWidth: .infinity)
            .aspectRatio(3/4, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func profilePhotoImage(_ photo: String) -> some View {
        if let url = AppConfig.resolvePhotoURL(photo) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    photoPlaceholder
                case .empty:
                    photoPlaceholder
                        .overlay { ProgressView().tint(.white.opacity(0.5)) }
                @unknown default:
                    photoPlaceholder
                }
            }
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        LinearGradient(
            colors: [Color(hex: "2A1F3D"), Color(hex: "1C1B2E"), Color(hex: "2D1B4E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white.opacity(0.15))
        }
    }

    // MARK: - Section Helpers

    private func sectionCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Reels Section

    private var reelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.purpleAccent)
                sectionHeader("Reels")
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                        Button {
                            tappedReelIndex = index
                            showReelFeed = true
                        } label: {
                            ReelThumbnailCard(reel: reel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Fetch

    private func fetchProfile() async {
        isLoading = true
        do {
            let result: DiscoverProfile = try await APIService.shared.get(
                path: "/profile/\(userId)"
            )
            profile = result
        } catch {
            do {
                let query = """
                query Discover($filters: DiscoverFilters) {
                  discover(filters: $filters) {
                    id name age bio location photos interests languages
                    compatibilityScore isVerified professionTitle voiceIntroUrl hasVoiceIntro hasReels
                  }
                }
                """
                let result: [String: Any] = try await APIService.shared.graphQL(
                    query: query,
                    variables: ["filters": ["userId": Int(userId) ?? 0, "limit": 1]]
                )
                if let discover = result["discover"] as? [[String: Any]],
                   let user = discover.first {
                    profile = DiscoverProfile(
                        id: "\(user["id"] ?? userId)",
                        name: user["name"] as? String ?? matchName,
                        age: user["age"] as? Int,
                        location: user["location"] as? String,
                        profession: user["professionTitle"] as? String,
                        compatibilityScore: (user["compatibilityScore"] as? Double).map { Int($0) },
                        bio: user["bio"] as? String,
                        interests: user["interests"] as? [String],
                        photos: user["photos"] as? [String],
                        isVerified: user["isVerified"] as? Bool ?? false,
                        voiceIntroUrl: user["voiceIntroUrl"] as? String,
                        hasVoiceIntro: user["hasVoiceIntro"] as? Bool ?? false,
                        hasReels: user["hasReels"] as? Bool ?? false,
                        languages: user["languages"] as? [String]
                    )
                }
            } catch {
                // fallback
            }
            if profile == nil {
                profile = makeDemoProfile()
            }
        }
        isLoading = false
    }

    private func fetchReels() async {
        // Fetch user-specific reels first
        var userReels: [Reel] = []
        do {
            struct ReelItem: Codable {
                let id: Int; let video_url: String?; let caption: String?
                let like_count: Int?; let view_count: Int?
            }
            struct ReelResponse: Codable {
                let reels: [ReelItem]
            }
            let response: ReelResponse = try await APIService.shared.get(
                path: "/reels/user/\(userId)"
            )
            userReels = response.reels.map { r in
                Reel(
                    id: "\(r.id)", userId: userId,
                    userName: profile?.name ?? matchName,
                    userAge: profile?.age ?? 0,
                    userPhoto: matchPhoto,
                    videoUrl: r.video_url ?? "",
                    caption: r.caption ?? "",
                    likes: r.like_count ?? 0, isLiked: false,
                    isVerified: profile?.isVerified ?? false,
                    location: profile?.location ?? "",
                    music: nil
                )
            }
        } catch {
            // For demo users, filter demo reels by userId
            userReels = []
        }

        // Fetch global feed reels
        var feedReels: [Reel] = []
        do {
            struct ReelFeedItem: Codable {
                let id: Int; let user_id: Int; let video_url: String?
                let thumbnail_url: String?; let duration_sec: Int?
                let caption: String?; let category: String?
                let like_count: Int?; let view_count: Int?
                let engagement_score: Double?
                let creator_name: String?; let creator_age: Int?
                let creator_photo: String?; let creator_verified: Bool?
                let creator_location: String?
            }
            struct ReelFeedResponse: Codable {
                let reels: [ReelFeedItem]
                let session_id: String?
                let count: Int?
            }
            let response: ReelFeedResponse = try await APIService.shared.get(path: "/reels/feed")
            feedReels = response.reels.map { r in
                Reel(id: "\(r.id)", userId: "\(r.user_id)", userName: r.creator_name ?? "Unknown",
                     userAge: r.creator_age ?? 0, userPhoto: r.creator_photo ?? "",
                     videoUrl: r.video_url ?? "", caption: r.caption ?? "",
                     likes: r.like_count ?? 0, isLiked: false,
                     isVerified: r.creator_verified ?? false, location: r.creator_location ?? "",
                     music: nil)
            }
        } catch {
            feedReels = []
        }

        // Combine: user's reels first, then feed reels (deduped)
        let userReelIds = Set(userReels.map { $0.id })
        let otherReels = feedReels.filter { !userReelIds.contains($0.id) }
        reels = userReels + otherReels
    }

    private func makeDemoProfile() -> DiscoverProfile {
        DiscoverProfile(
            id: userId,
            name: matchName,
            age: 25,
            location: "Nearby",
            bio: "Hey there! I'm looking to meet new people and see where things go.",
            interests: ["Travel", "Music", "Food", "Movies"],
            photos: [matchPhoto],
            isVerified: false,
            hasVoiceIntro: false,
            hasReels: false,
            languages: ["English"]
        )
    }
}

// MARK: - Voice Intro Player

private struct VoiceIntroPlayer: View {
    let url: String
    @State private var isPlaying = false
    @State private var player: AVPlayer?

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.purpleAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Intro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(isPlaying ? "Playing..." : "Tap to listen")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppColors.purpleAccent.opacity(isPlaying ? 0.8 : 0.3))
                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                            .animation(isPlaying ?
                                .easeInOut(duration: 0.3).repeatForever().delay(Double(i) * 0.05) :
                                .default, value: isPlaying)
                    }
                }
            }
            .padding(14)
            .background(AppColors.purpleAccent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if let audioURL = AppConfig.resolvePhotoURL(url) {
                player = AVPlayer(url: audioURL)
                player?.play()
                isPlaying = true

                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player?.currentItem,
                    queue: .main
                ) { _ in
                    isPlaying = false
                }
            }
        }
    }
}

// MARK: - Reel Thumbnail Card

struct ReelThumbnailCard: View {
    let reel: Reel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                if !reel.caption.isEmpty {
                    Text(reel.caption)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(reel.likes)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(width: 140, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Profile Reel Feed View (Full-Screen with Global/Local)

struct ProfileReelFeedView: View {
    let initialReels: [Reel]
    let startIndex: Int
    let userName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var pool = ReelPlayerPool()
    @State private var reels: [Reel] = []
    @State private var currentIndex = 0
    @State private var feedScope: ReelFeedScope = .global
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if reels.isEmpty && isLoading {
                ProgressView().tint(.white).scaleEffect(1.5)
            } else if reels.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Reels")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            } else {
                GeometryReader { geo in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                            ReelCard(
                                reel: Binding(
                                    get: { reels[index] },
                                    set: { reels[index] = $0 }
                                ),
                                isActive: index == currentIndex,
                                player: pool.player(for: index),
                                onProfileTap: nil
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
            }

            // Header overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Text("Reels")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Global / Local toggle
                    HStack(spacing: 0) {
                        ForEach(ReelFeedScope.allCases, id: \.self) { scope in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { feedScope = scope }
                                currentIndex = 0
                                Task { await fetchFeedReels() }
                            } label: {
                                Text(scope.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(feedScope == scope ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(feedScope == scope ? Color.white.opacity(0.2) : Color.clear)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
        .task {
            reels = initialReels
            currentIndex = min(startIndex, max(0, reels.count - 1))
            pool.activate(currentIndex: currentIndex, urls: reels.map { $0.videoUrl })
        }
        .onChange(of: currentIndex) { _, idx in
            pool.activate(currentIndex: idx, urls: reels.map { $0.videoUrl })
        }
        .onDisappear { pool.pauseAll() }
    }

    private func fetchFeedReels() async {
        isLoading = true
        do {
            struct ReelFeedItem: Codable {
                let id: Int; let user_id: Int; let video_url: String?
                let thumbnail_url: String?; let duration_sec: Int?
                let caption: String?; let category: String?
                let like_count: Int?; let view_count: Int?
                let engagement_score: Double?
                let creator_name: String?; let creator_age: Int?
                let creator_photo: String?; let creator_verified: Bool?
                let creator_location: String?
            }
            struct ReelFeedResponse: Codable {
                let reels: [ReelFeedItem]
                let session_id: String?
                let count: Int?
            }
            let path = feedScope == .local ? "/reels/feed?scope=local" : "/reels/feed"
            let response: ReelFeedResponse = try await APIService.shared.get(path: path)
            let fetched = response.reels.map { r in
                Reel(id: "\(r.id)", userId: "\(r.user_id)", userName: r.creator_name ?? "Unknown",
                     userAge: r.creator_age ?? 0, userPhoto: r.creator_photo ?? "",
                     videoUrl: r.video_url ?? "", caption: r.caption ?? "",
                     likes: r.like_count ?? 0, isLiked: false,
                     isVerified: r.creator_verified ?? false, location: r.creator_location ?? "",
                     music: nil)
            }
            reels = fetched.isEmpty ? filteredDemos : fetched
        } catch {
            reels = filteredDemos
        }
        isLoading = false
        pool.reset()
        pool.activate(currentIndex: 0, urls: reels.map { $0.videoUrl })
    }

    private var filteredDemos: [Reel] { [] }
}
