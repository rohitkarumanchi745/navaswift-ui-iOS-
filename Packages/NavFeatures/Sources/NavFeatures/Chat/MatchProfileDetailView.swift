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

    @Environment(\.dismiss) private var dismiss
    @State private var profile: DiscoverProfile?
    @State private var reels: [Reel] = []
    @State private var isLoading = true
    @State private var selectedPhotoIndex = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Photo gallery
                photoGallery

                // Profile info
                profileInfo
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Bio
                if let bio = profile?.bio, !bio.isEmpty {
                    bioSection(bio)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                // Interests
                if let interests = profile?.interests, !interests.isEmpty {
                    interestsSection(interests)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                // Languages
                if let languages = profile?.languages, !languages.isEmpty {
                    languagesSection(languages)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                // Reels
                if !reels.isEmpty {
                    reelsSection
                        .padding(.top, 24)
                }

                Spacer().frame(height: 40)
            }
        }
        .background(AppColors.darkBg)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 56)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .task {
            await fetchProfile()
            await fetchReels()
        }
    }

    // MARK: - Photo Gallery

    private var photoGallery: some View {
        ZStack(alignment: .bottom) {
            let photos = profile?.photos ?? [matchPhoto]
            let validPhotos = photos.isEmpty ? [matchPhoto] : photos

            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(validPhotos.enumerated()), id: \.offset) { index, photo in
                    AsyncImage(url: AppConfig.resolvePhotoURL(photo)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(AppColors.darkCard)
                            .overlay { ProgressView() }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 480)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Photo indicators
            if validPhotos.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<validPhotos.count, id: \.self) { i in
                        Capsule()
                            .fill(i == selectedPhotoIndex ? .white : .white.opacity(0.4))
                            .frame(width: i == selectedPhotoIndex ? 24 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.2), value: selectedPhotoIndex)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Profile Info

    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(profile?.name ?? matchName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                if let age = profile?.age {
                    Text("\(age)")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.6))
                }

                if profile?.isVerified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.verified)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                if let location = profile?.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text(location)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if let profession = profile?.profession, !profession.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text(profession)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            if let score = profile?.compatibilityScore, score > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.gold)
                    Text("\(score)% Match")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.gold.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 4)
            }

            // Voice intro
            if profile?.hasVoiceIntro == true, let voiceUrl = profile?.voiceIntroUrl, !voiceUrl.isEmpty {
                VoiceIntroPlayer(url: voiceUrl)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Sections

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("About")
            Text(bio)
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func interestsSection(_ interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Interests")
            FlowLayout(spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func languagesSection(_ languages: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Languages")
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.secondary)
                Text(languages.joined(separator: " · "))
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.darkTextMuted)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Reels Section

    private var reelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.primary)
                Text("Reels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.darkTextMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(reels) { reel in
                        ReelThumbnailCard(reel: reel)
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
            let query = """
            query UserProfile($userId: Int!) {
                userProfile(userId: $userId) {
                    id name age gender bio location
                    professionTitle interests photos
                    isVerified voiceIntroUrl
                    languages lookingFor heightCm
                    compatibilityScore hasVoiceIntro hasReels
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(
                query: query,
                variables: ["userId": Int(userId) ?? 0]
            )
            if let user = result["userProfile"] as? [String: Any] {
                profile = DiscoverProfile(
                    id: "\(user["id"] ?? userId)",
                    name: user["name"] as? String ?? matchName,
                    age: user["age"] as? Int,
                    location: user["location"] as? String,
                    profession: user["professionTitle"] as? String,
                    compatibilityScore: user["compatibilityScore"] as? Int,
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
            // Use fallback demo profile if API fails
            if profile == nil {
                profile = makeDemoProfile()
            }
        }
        isLoading = false
    }

    private func fetchReels() async {
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
            reels = response.reels.map { r in
                Reel(
                    id: "\(r.id)", userId: userId,
                    userName: profile?.name ?? matchName,
                    userAge: profile?.age ?? 0,
                    userPhoto: matchPhoto,
                    videoUrl: r.video_url ?? "",
                    caption: r.caption ?? "",
                    likes: r.like_count ?? 0, isLiked: false,
                    isVerified: profile?.isVerified ?? false,
                    location: profile?.location ?? ""
                )
            }
        } catch {
            // No reels — that's fine
        }
    }

    private func makeDemoProfile() -> DiscoverProfile {
        // Build a reasonable demo profile from the match info we already have
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
                    .foregroundStyle(AppColors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Intro")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isPlaying ? "Playing..." : "Tap to listen")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppColors.primary.opacity(isPlaying ? 0.8 : 0.3))
                            .frame(width: 3, height: CGFloat.random(in: 8...24))
                            .animation(isPlaying ?
                                .easeInOut(duration: 0.3).repeatForever().delay(Double(i) * 0.05) :
                                .default, value: isPlaying)
                    }
                }
            }
            .padding(14)
            .background(AppColors.primary.opacity(0.08))
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
            // Gradient background (thumbnail placeholder)
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Play icon
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Caption + likes
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
