import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import UniformTypeIdentifiers
import NavCore
import NavNetworking
import NavServices

// MARK: - Full-Screen Video Player (resizeAspectFill)
private struct FullScreenVideoPlayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.backgroundColor = .black
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

// MARK: - Reel Model
struct Reel: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userAge: Int
    let userPhoto: String
    let videoUrl: String
    let caption: String
    var likes: Int
    var isLiked: Bool
    let isVerified: Bool
    let location: String
}

// MARK: - Video Player Manager
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    private var currentURL: String?

    func play(url: String) {
        guard url != currentURL, let videoURL = URL(string: url) else {
            player?.play()
            return
        }
        currentURL = url
        player = AVPlayer(url: videoURL)
        player?.isMuted = false
        player?.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        player = nil
        currentURL = nil
    }
}

// MARK: - Feed Scope
enum ReelFeedScope: String, CaseIterable {
    case global = "Global"
    case local = "Local"
}

// MARK: - Draggable Tab Bar Overlay
private struct DraggableTabBar: View {
    @Binding var selectedTab: Int
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0

    private let tabBarHeight: CGFloat = 56
    private let handleHeight: CGFloat = 20

    private let tabs: [(icon: String, label: String, tag: Int)] = [
        ("flame.fill", "Discover", 0),
        ("heart.fill", "Likes", 1),
        ("message.fill", "Chat", 2),
        ("play.rectangle.fill", "Reels", 3),
        ("person.fill", "Profile", 4),
    ]

    private var totalHeight: CGFloat { tabBarHeight + handleHeight }

    private var currentOffset: CGFloat {
        isVisible ? 0 : tabBarHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pull handle
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.vertical, 8)

            // Tab buttons
            HStack(spacing: 0) {
                ForEach(tabs, id: \.tag) { tab in
                    Button {
                        if tab.tag == 3 {
                            // Already on Reels, just hide the bar
                            withAnimation(.easeOut(duration: 0.25)) { isVisible = false }
                        } else {
                            selectedTab = tab.tag
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.label)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(tab.tag == 3 ? AppColors.primary : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: tabBarHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .offset(y: currentOffset + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    dragOffset = 0
                    let threshold: CGFloat = 20
                    withAnimation(.easeOut(duration: 0.25)) {
                        if isVisible {
                            // Swipe down to hide
                            if value.translation.height > threshold {
                                isVisible = false
                            }
                        } else {
                            // Swipe up to show
                            if value.translation.height < -threshold {
                                isVisible = true
                            }
                        }
                    }
                }
        )
        .animation(.easeOut(duration: 0.25), value: isVisible)
    }
}

// MARK: - ReelsView
struct ReelsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var uploadService: ReelUploadService
    @State private var currentIndex = 0
    @State private var reels: [Reel] = []
    @State private var showUploadSheet = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var feedScope: ReelFeedScope = .global
    @State private var showUserReels = false
    @State private var selectedReelUser: Reel?
    @State private var showPremiumGate = false
    @State private var showProfileDetail = false
    @State private var profileDetailReel: Reel?
    @State private var showInbox = false
    @State private var unreadReelMessages = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white).scaleEffect(1.5)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 48)).foregroundColor(.gray)
                    Text("Could not load reels")
                        .font(.headline).foregroundColor(.white)
                    Text(error).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                    Button("Retry") { Task { await fetchReels() } }
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(AppColors.primary).clipShape(Capsule())
                }
                .padding(32)
            } else if reels.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                            ReelCard(
                                reel: binding(for: index),
                                isActive: index == currentIndex,
                                onProfileTap: { handleProfileTap(reel: reels[index]) }
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
                    Text("Reels").font(.title2.bold()).foregroundColor(.white)

                    Spacer()

                    // Global / Local toggle
                    HStack(spacing: 0) {
                        ForEach(ReelFeedScope.allCases, id: \.self) { scope in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { feedScope = scope }
                                currentIndex = 0
                                Task { await fetchReels() }
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

                    // Inbox button with unread badge
                    Button { showInbox = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)

                            if unreadReelMessages > 0 {
                                Text("\(min(unreadReelMessages, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppColors.error)
                                    .clipShape(Capsule())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }

                    Button { showUploadSheet = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                }
                .padding(.horizontal).padding(.top, 8)
                Spacer()
            }

            // Draggable tab bar at bottom
            VStack {
                Spacer()
                DraggableTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Floating upload progress pill
            if uploadService.phase != .idle {
                VStack {
                    Spacer()
                    ReelUploadProgressPill(uploadService: uploadService)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: uploadService.phase.isActive)
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadReelView()
                .environmentObject(uploadService)
        }
        .sheet(isPresented: $showUserReels) {
            if let user = selectedReelUser {
                UserReelsView(userId: user.userId, userName: user.userName, userPhoto: user.userPhoto)
                    .environmentObject(storeKit)
            }
        }
        .sheet(isPresented: $showPremiumGate) {
            PremiumView()
        }
        .sheet(isPresented: $showProfileDetail) {
            if let reel = profileDetailReel {
                NavigationStack {
                    MatchProfileDetailView(
                        userId: reel.userId,
                        matchName: reel.userName,
                        matchPhoto: reel.userPhoto
                    )
                }
            }
        }
        .sheet(isPresented: $showInbox) {
            NavigationStack {
                ReelInboxView()
            }
        }
        .task {
            await fetchReels()
            await fetchUnreadCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: ReelUploadService.didFinishUploadNotification)) { _ in
            Task { await fetchReels() }
        }
        .onChange(of: feedScope) { _, _ in
            currentIndex = 0
        }
    }

    private func binding(for index: Int) -> Binding<Reel> {
        Binding(get: { reels[index] }, set: { reels[index] = $0 })
    }

    private func handleProfileTap(reel: Reel) {
        profileDetailReel = reel
        showProfileDetail = true
    }

    private func fetchUnreadCount() async {
        do {
            let response: ReelInboxResponse = try await APIService.shared.get(
                path: "/reels/inbox?limit=1&unread_only=true"
            )
            unreadReelMessages = response.unreadCount ?? 0
        } catch {
            // Silently fail — badge just won't show
        }
    }

    private func fetchReels() async {
        isLoading = reels.isEmpty
        errorMessage = nil
        let currentUserId = auth.user?.id ?? ""
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
            let fetched = response.reels
                .filter { "\($0.user_id)" != currentUserId }
                .map { r in
                    Reel(id: "\(r.id)", userId: "\(r.user_id)", userName: r.creator_name ?? "Unknown",
                         userAge: r.creator_age ?? 0, userPhoto: r.creator_photo ?? "",
                         videoUrl: r.video_url ?? "", caption: r.caption ?? "",
                         likes: r.like_count ?? 0, isLiked: false,
                         isVerified: r.creator_verified ?? false, location: r.creator_location ?? "")
                }
            reels = fetched.isEmpty ? filteredDemos : fetched
        } catch {
            if reels.isEmpty {
                reels = filteredDemos
            }
        }
        isLoading = false
    }

    /// Filter demo reels by location for "Local" scope demo
    private var filteredDemos: [Reel] {
        if feedScope == .local {
            let localCities = ["Hyderabad", "Vizag"]
            let local = Reel.demos.filter { localCities.contains($0.location) }
            return local.isEmpty ? Reel.demos : local
        }
        return Reel.demos
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.fill").font(.system(size: 60)).foregroundColor(.gray)
            Text("No Reels Yet").font(.title2.bold()).foregroundColor(.white)
            Text("Be the first to share a moment!").foregroundColor(.gray)
            Button { showUploadSheet = true } label: {
                Label("Upload Reel", systemImage: "plus")
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(AppColors.brandGradient).clipShape(Capsule())
            }
        }
    }
}

// MARK: - User Reels View (Premium Only)
struct UserReelsView: View {
    let userId: String
    let userName: String
    let userPhoto: String
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var userReels: [Reel] = []
    @State private var isLoading = true
    @State private var currentIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        AsyncImage(url: AppConfig.resolvePhotoURL(userPhoto)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        Text(userName)
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        ProgressView().tint(.white)
                    }
                } else if userReels.isEmpty {
                    VStack(spacing: 16) {
                        AsyncImage(url: AppConfig.resolvePhotoURL(userPhoto)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        Text(userName)
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        Text("No reels yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(userReels.enumerated()), id: \.element.id) { index, reel in
                            ReelCard(
                                reel: Binding(
                                    get: { userReels[index] },
                                    set: { userReels[index] = $0 }
                                ),
                                isActive: index == currentIndex,
                                onProfileTap: nil
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }

                // Header
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }

                        AsyncImage(url: AppConfig.resolvePhotoURL(userPhoto)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())

                        Text("\(userName)'s Reels")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        if !userReels.isEmpty {
                            Text("\(currentIndex + 1)/\(userReels.count)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.4))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal).padding(.top, 8)
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .task { await fetchUserReels() }
        }
    }

    private func fetchUserReels() async {
        isLoading = true
        do {
            struct ReelItem: Codable {
                let id: Int; let video_url: String?; let caption: String?
                let like_count: Int?; let view_count: Int?
            }
            struct ReelResponse: Codable { let reels: [ReelItem] }
            let response: ReelResponse = try await APIService.shared.get(
                path: "/reels/user/\(userId)"
            )
            userReels = response.reels.map { r in
                Reel(
                    id: "\(r.id)", userId: userId,
                    userName: userName, userAge: 0,
                    userPhoto: userPhoto,
                    videoUrl: r.video_url ?? "",
                    caption: r.caption ?? "",
                    likes: r.like_count ?? 0, isLiked: false,
                    isVerified: false, location: ""
                )
            }
        } catch {
            // For demo users, filter demo reels by userId
            userReels = Reel.demos.filter { $0.userId == userId }
        }
        isLoading = false
    }
}

// MARK: - ReelCard
struct ReelCard: View {
    @Binding var reel: Reel
    let isActive: Bool
    var onProfileTap: (() -> Void)?
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showHeart = false
    @State private var showMessageSheet = false
    @State private var showLikeCreator = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if !reel.videoUrl.isEmpty, URL(string: reel.videoUrl) != nil {
                    FullScreenVideoPlayer(player: playerManager.player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .onAppear { if isActive { playerManager.play(url: reel.videoUrl) } }
                } else {
                    LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack { Spacer()
                        Image(systemName: "play.circle.fill").font(.system(size: 72)).foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                }

                if showHeart {
                    Image(systemName: "heart.fill").font(.system(size: 80)).foregroundColor(.red)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                onProfileTap?()
                            } label: {
                                HStack(spacing: 8) {
                                    AsyncImage(url: AppConfig.resolvePhotoURL(reel.userPhoto)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: { Circle().fill(Color.gray.opacity(0.3)) }
                                    .frame(width: 40, height: 40).clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(reel.userName).font(.headline).foregroundColor(.white)
                                            if reel.isVerified {
                                                Image(systemName: "checkmark.seal.fill").font(.caption).foregroundColor(AppColors.secondary)
                                            }
                                            Text("\(reel.userAge)").font(.subheadline).foregroundColor(.white.opacity(0.8))
                                        }
                                        if !reel.location.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "mappin").font(.caption2)
                                                Text(reel.location).font(.caption)
                                            }.foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                            }
                            if !reel.caption.isEmpty {
                                Text(reel.caption).font(.subheadline).foregroundColor(.white).lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 20) {
                            reelAction(icon: reel.isLiked ? "heart.fill" : "heart", count: reel.likes, color: reel.isLiked ? .red : .white) { toggleLike() }
                            reelAction(icon: "bubble.right", count: nil, color: .white) { showMessageSheet = true }
                            reelAction(icon: "paperplane", count: nil, color: .white) {}
                        }
                    }
                    .padding().padding(.bottom, 30)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onTapGesture(count: 2) {
            if !reel.isLiked { toggleLike() }
            withAnimation(.spring(response: 0.3)) { showHeart = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showHeart = false } }
        }
        .gesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    // Swipe up to like creator
                    if value.translation.height < -80 && abs(value.translation.width) < abs(value.translation.height) {
                        likeCreator()
                    }
                }
        )
        .overlay {
            if showLikeCreator {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppColors.purpleAccent)
                    Text("Liked \(reel.userName)!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(20)
                .background(.ultraThinMaterial.opacity(0.9))
                .environment(\.colorScheme, .dark)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: isActive) { _, active in
            if active { playerManager.play(url: reel.videoUrl); trackView() }
            else { playerManager.pause() }
        }
        .onDisappear { playerManager.stop() }
        .sheet(isPresented: $showMessageSheet) {
            ReelMessageComposer(reel: reel, isPresented: $showMessageSheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppColors.darkBg)
        }
    }

    private func toggleLike() {
        withAnimation(.spring(response: 0.3)) { reel.isLiked.toggle(); reel.likes += reel.isLiked ? 1 : -1 }
        Task {
            struct R: Codable { let success: Bool? }
            let path = reel.isLiked ? "/reels/like" : "/reels/unlike"
            let _: R? = try? await APIService.shared.post(path: path, body: ["reel_id": Int(reel.id) ?? 0])
        }
    }

    private func likeCreator() {
        withAnimation(.spring(response: 0.3)) { showLikeCreator = true }
        Task {
            struct R: Codable { let success: Bool? }
            let _: R? = try? await APIService.shared.post(
                path: "/reels/\(reel.id)/like-creator",
                body: ["reel_id": Int(reel.id) ?? 0]
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showLikeCreator = false }
        }
    }

    private func trackView() {
        Task {
            struct R: Codable { let success: Bool? }
            let _: R? = try? await APIService.shared.post(path: "/reels/view", body: ["reel_id": Int(reel.id) ?? 0])
        }
    }

    private func reelAction(icon: String, count: Int?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                if let count { Text(formatCount(count)).font(.caption2).foregroundColor(.white.opacity(0.8)) }
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }
}

// MARK: - Demo Reels
extension Reel {
    static let demos: [Reel] = [
        Reel(
            id: "demo-reel-1", userId: "demo-1", userName: "Priya", userAge: 26,
            userPhoto: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            caption: "Weekend vibes in the city! 🌇 #travel #adventure",
            likes: 342, isLiked: false, isVerified: true, location: "Hyderabad"
        ),
        Reel(
            id: "demo-reel-2", userId: "demo-2", userName: "Arjun", userAge: 29,
            userPhoto: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            caption: "Morning trail run with the best view 🏃‍♂️⛰️",
            likes: 518, isLiked: false, isVerified: true, location: "Bangalore"
        ),
        Reel(
            id: "demo-reel-3", userId: "demo-3", userName: "Meera", userAge: 27,
            userPhoto: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            caption: "Cooking something special tonight 🍳✨",
            likes: 276, isLiked: false, isVerified: false, location: "Chennai"
        ),
        Reel(
            id: "demo-reel-4", userId: "demo-4", userName: "Sneha", userAge: 25,
            userPhoto: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            caption: "Life is better with music 🎵 #singer #life",
            likes: 891, isLiked: false, isVerified: true, location: "Mumbai"
        ),
        Reel(
            id: "demo-reel-5", userId: "demo-5", userName: "Kavya", userAge: 24,
            userPhoto: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
            caption: "Sunset chasing is my cardio 🌅✨ #golden #wanderlust",
            likes: 1203, isLiked: false, isVerified: true, location: "Goa"
        ),
        Reel(
            id: "demo-reel-6", userId: "demo-6", userName: "Rohan", userAge: 28,
            userPhoto: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            caption: "Late night coding session turned into art 🎨💻 #developer #creative",
            likes: 467, isLiked: false, isVerified: false, location: "Pune"
        ),
        Reel(
            id: "demo-reel-7", userId: "demo-7", userName: "Ananya", userAge: 23,
            userPhoto: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
            caption: "Road trip diaries 🚗💨 who's coming next time?",
            likes: 729, isLiked: false, isVerified: true, location: "Delhi"
        ),
        Reel(
            id: "demo-reel-8", userId: "demo-8", userName: "Vikram", userAge: 30,
            userPhoto: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
            caption: "When the gym hits different at 5 AM 💪🔥 #fitness #grind",
            likes: 1547, isLiked: false, isVerified: true, location: "Hyderabad"
        ),
        Reel(
            id: "demo-reel-9", userId: "demo-9", userName: "Diya", userAge: 26,
            userPhoto: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
            caption: "Coffee + books = perfect Sunday ☕📖 #cozy #bookworm",
            likes: 385, isLiked: false, isVerified: false, location: "Kolkata"
        ),
        Reel(
            id: "demo-reel-10", userId: "demo-10", userName: "Aditya", userAge: 27,
            userPhoto: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
            caption: "Beach bonfire with the squad 🏖️🔥 #friends #goodtimes",
            likes: 2103, isLiked: false, isVerified: true, location: "Vizag"
        ),
        Reel(
            id: "demo-reel-11", userId: "demo-11", userName: "Ishita", userAge: 24,
            userPhoto: "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            caption: "Dancing in the rain because why not 💃🌧️ #spontaneous",
            likes: 1892, isLiked: false, isVerified: true, location: "Mumbai"
        ),
        Reel(
            id: "demo-reel-12", userId: "demo-12", userName: "Karthik", userAge: 26,
            userPhoto: "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            caption: "Street photography at golden hour 📸 the city never sleeps",
            likes: 634, isLiked: false, isVerified: true, location: "Bangalore"
        ),
        Reel(
            id: "demo-reel-13", userId: "demo-13", userName: "Riya", userAge: 22,
            userPhoto: "https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            caption: "First day at the new studio! 🎨 #art #newbeginnings",
            likes: 445, isLiked: false, isVerified: false, location: "Jaipur"
        ),
        Reel(
            id: "demo-reel-14", userId: "demo-14", userName: "Sahil", userAge: 28,
            userPhoto: "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            caption: "Surfing lesson gone wrong... or right? 🏄‍♂️😂 #beachlife",
            likes: 2340, isLiked: false, isVerified: true, location: "Goa"
        ),
        Reel(
            id: "demo-reel-15", userId: "demo-15", userName: "Tara", userAge: 25,
            userPhoto: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            caption: "Trying every cafe in the city, one latte at a time ☕🗺️",
            likes: 567, isLiked: false, isVerified: true, location: "Delhi"
        ),
        Reel(
            id: "demo-reel-16", userId: "demo-16", userName: "Nikhil", userAge: 27,
            userPhoto: "https://images.unsplash.com/photo-1521119989659-a83eee488004?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            caption: "Motorcycle ride through the Western Ghats 🏍️🌿 #ride #freedom",
            likes: 1456, isLiked: false, isVerified: false, location: "Pune"
        ),
        Reel(
            id: "demo-reel-17", userId: "demo-17", userName: "Sanya", userAge: 23,
            userPhoto: "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
            caption: "Yoga at sunrise hits different 🧘‍♀️🌅 #mindfulness #peace",
            likes: 987, isLiked: false, isVerified: true, location: "Rishikesh"
        ),
        Reel(
            id: "demo-reel-18", userId: "demo-18", userName: "Dev", userAge: 31,
            userPhoto: "https://images.unsplash.com/photo-1480455624313-e29b44bbafae?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            caption: "Finished building my first guitar from scratch 🎸🔨 #diy",
            likes: 3201, isLiked: false, isVerified: true, location: "Chennai"
        ),
        Reel(
            id: "demo-reel-19", userId: "demo-19", userName: "Nisha", userAge: 26,
            userPhoto: "https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
            caption: "Backpacking across Meghalaya 🎒🌊 #northeast #explore",
            likes: 1678, isLiked: false, isVerified: true, location: "Shillong"
        ),
        Reel(
            id: "demo-reel-20", userId: "demo-20", userName: "Raj", userAge: 29,
            userPhoto: "https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4",
            caption: "Night market food tour — my stomach is happy 🍜🔥",
            likes: 812, isLiked: false, isVerified: false, location: "Hyderabad"
        ),
        Reel(
            id: "demo-reel-21", userId: "demo-21", userName: "Pooja", userAge: 24,
            userPhoto: "https://images.unsplash.com/photo-1514315384763-ba401779410f?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4",
            caption: "Learning pottery and it's so therapeutic 🏺✨ #handmade",
            likes: 543, isLiked: false, isVerified: true, location: "Udaipur"
        ),
        Reel(
            id: "demo-reel-22", userId: "demo-22", userName: "Varun", userAge: 27,
            userPhoto: "https://images.unsplash.com/photo-1463453091185-61582044d556?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4",
            caption: "Paragliding over Bir Billing — absolutely unreal 🪂☁️",
            likes: 4521, isLiked: false, isVerified: true, location: "Dharamshala"
        ),
        Reel(
            id: "demo-reel-23", userId: "demo-23", userName: "Aisha", userAge: 25,
            userPhoto: "https://images.unsplash.com/photo-1496440737103-cd596325d314?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            caption: "My plant babies are thriving 🌱🪴 #plantmom #green",
            likes: 321, isLiked: false, isVerified: false, location: "Kolkata"
        ),
        Reel(
            id: "demo-reel-24", userId: "demo-24", userName: "Manish", userAge: 30,
            userPhoto: "https://images.unsplash.com/photo-1506277886164-e25aa3f4ef7f?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            caption: "Basketball pickup game at midnight 🏀🌙 #hoops #nightowl",
            likes: 1102, isLiked: false, isVerified: true, location: "Bangalore"
        ),
        Reel(
            id: "demo-reel-25", userId: "demo-25", userName: "Shreya", userAge: 22,
            userPhoto: "https://images.unsplash.com/photo-1524638431109-93d95c968f03?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            caption: "Diwali prep starts early in our house 🪔🎆 #festival #family",
            likes: 2876, isLiked: false, isVerified: true, location: "Vizag"
        ),
        Reel(
            id: "demo-reel-26", userId: "demo-26", userName: "Harsh", userAge: 28,
            userPhoto: "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            caption: "Trekking Hampta Pass was the hardest thing I've ever done 🏔️ #trek",
            likes: 1934, isLiked: false, isVerified: false, location: "Manali"
        ),
        Reel(
            id: "demo-reel-27", userId: "demo-27", userName: "Lakshmi", userAge: 26,
            userPhoto: "https://images.unsplash.com/photo-1499952127939-9bbf5af6c51c?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            caption: "Classical dance practice — Bharatanatyam never gets old 💃🎶",
            likes: 2210, isLiked: false, isVerified: true, location: "Chennai"
        ),
        Reel(
            id: "demo-reel-28", userId: "demo-28", userName: "Kabir", userAge: 25,
            userPhoto: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            caption: "Skateboarding through empty streets at dawn 🛹🌤️ #skate",
            likes: 756, isLiked: false, isVerified: true, location: "Mumbai"
        ),
        Reel(
            id: "demo-reel-29", userId: "demo-29", userName: "Tanvi", userAge: 23,
            userPhoto: "https://images.unsplash.com/photo-1485893086445-ed75865251e0?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
            caption: "Adopted this little furball today 🐶❤️ say hi to Mochi!",
            likes: 5432, isLiked: false, isVerified: true, location: "Pune"
        ),
        Reel(
            id: "demo-reel-30", userId: "demo-30", userName: "Aman", userAge: 29,
            userPhoto: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
            videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            caption: "Stargazing in Spiti Valley — zero light pollution 🌌✨ #astro",
            likes: 3890, isLiked: false, isVerified: true, location: "Spiti"
        ),
    ]
}

// MARK: - Upload Progress Pill
struct ReelUploadProgressPill: View {
    @ObservedObject var uploadService: ReelUploadService

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail preview
            if let thumb = uploadService.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(progressColor)
                            .frame(width: geo.size.width * uploadService.phase.progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: uploadService.phase.progress)
                    }
                }
                .frame(height: 4)
            }

            Spacer(minLength: 0)

            // Status icon or dismiss button
            statusIcon
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private var statusText: String {
        switch uploadService.phase {
        case .idle: return ""
        case .compressing(let p): return "Compressing \(Int(p * 100))%"
        case .awaitingFilter: return "Pick a filter"
        case .exportingFilter(let p): return "Applying filter \(Int(p * 100))%"
        case .readyToPost: return "Ready to post"
        case .uploading(let p): return "Uploading \(Int(p * 100))%"
        case .done: return "Upload complete!"
        case .failed: return "Upload failed"
        }
    }

    private var progressColor: Color {
        switch uploadService.phase {
        case .done: return .green
        case .failed: return .red
        default: return AppColors.primary
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch uploadService.phase {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.green)
        case .failed:
            Button { uploadService.dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
            }
        default:
            ProgressView()
                .tint(.white)
                .scaleEffect(0.8)
        }
    }
}

// MARK: - UploadReelView
struct UploadReelView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var uploadService: ReelUploadService
    @EnvironmentObject var auth: AuthManager
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var hasPickedVideo = false
    @State private var caption = ""
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var showCamera = false
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if !hasPickedVideo {
                    videoPickerView
                } else {
                    filterEditorView
                }
            }
            .navigationTitle(hasPickedVideo ? "New Reel" : "Select Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.darkBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        uploadService.dismiss()
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                if hasPickedVideo {
                    ToolbarItem(placement: .topBarTrailing) {
                        postButton
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                VideoCameraRecorder { videoURL in
                    if let url = videoURL {
                        uploadService.prepare(localURL: url)
                        uploadService.applyFilter(.original)
                        hasPickedVideo = true
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showDocumentPicker) {
                VideoDocumentPicker { url in
                    uploadService.prepare(localURL: url)
                    uploadService.applyFilter(.original)
                    hasPickedVideo = true
                }
            }
        }
    }

    // MARK: - Video Picker

    private var videoPickerView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose a source")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Gallery (Photos Library)
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    sourceOptionCard(
                        icon: "photo.on.rectangle.angled",
                        title: "Photo Library",
                        subtitle: "Select from your gallery",
                        color: AppColors.purpleAccent
                    )
                }
                .onChange(of: selectedItem) { _, item in
                    Task {
                        guard let item else { return }
                        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                            uploadService.prepare(localURL: movie.url)
                            uploadService.applyFilter(.original)
                            hasPickedVideo = true
                        }
                    }
                }

                // Files / Drive
                Button { showDocumentPicker = true } label: {
                    sourceOptionCard(
                        icon: "folder.fill",
                        title: "Files & Drive",
                        subtitle: "Import from Files, iCloud, or Drive",
                        color: .blue
                    )
                }

                // Camera Recording
                Button { showCamera = true } label: {
                    sourceOptionCard(
                        icon: "video.fill",
                        title: "Record Video",
                        subtitle: "Capture from camera",
                        color: .red
                    )
                }

                Text("Max 30 seconds")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 8)
            }
            .padding(24)
        }
    }

    private func sourceOptionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Filter Editor

    private var filterEditorView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Preview with phase badge
                    previewWithBadge
                        .padding(.top, 8)

                    // Progress bar
                    progressBar

                    // Caption
                    TextField("Write a caption...", text: $caption, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(AppColors.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .tint(AppColors.purpleAccent)
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: .infinity)

            Divider().overlay(AppColors.darkDivider)

            // Filter carousel
            filterCarousel
                .frame(height: 110)
                .padding(.bottom, 8)
        }
        .task {
            await generateFilterThumbnails()
        }
    }

    // MARK: - Preview with Phase Badge

    private var previewWithBadge: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumb = uploadService.thumbnail {
                    let filtered = uploadService.selectedFilter.applyToImage(thumb)
                    Image(uiImage: filtered)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.darkCard)
                        .frame(height: 260)
                        .overlay {
                            ProgressView().tint(.white)
                        }
                }
            }

            phaseBadge
                .padding(12)
        }
    }

    // MARK: - Phase Badge

    private var phaseBadge: some View {
        HStack(spacing: 6) {
            switch uploadService.phase {
            case .compressing(let p):
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
                Text("Compressing \(Int(p * 100))%")
            case .awaitingFilter:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready")
            case .exportingFilter(let p):
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
                Text("Applying \(Int(p * 100))%")
            case .readyToPost:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready to post")
            case .uploading(let p):
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
                Text("Uploading \(Int(p * 100))%")
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Done!")
            case .failed(let msg):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(msg).lineLimit(1)
            default:
                EmptyView()
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                Capsule()
                    .fill(barColor)
                    .frame(width: geo.size.width * uploadService.phase.progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: uploadService.phase.progress)
            }
        }
        .frame(height: 4)
        .opacity(uploadService.phase == .idle || uploadService.phase == .awaitingFilter || uploadService.phase == .readyToPost ? 0 : 1)
    }

    private var barColor: Color {
        switch uploadService.phase {
        case .done: return .green
        case .failed: return .red
        default: return AppColors.purpleAccent
        }
    }

    // MARK: - Filter Carousel

    private var filterCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VideoFilter.allCases) { filter in
                    filterSwatch(filter: filter)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func filterSwatch(filter: VideoFilter) -> some View {
        let isSelected = uploadService.selectedFilter == filter

        return Button {
            uploadService.applyFilter(filter)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let thumb = filterThumbnails[filter] {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else if let thumb = uploadService.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.darkCard)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? AppColors.purpleAccent : Color.clear, lineWidth: 2)
                )

                Text(filter.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.purpleAccent : .white.opacity(0.7))
            }
        }
    }

    // MARK: - Post Button

    private var postButton: some View {
        let isReady: Bool = {
            switch uploadService.phase {
            case .readyToPost, .done: return true
            default: return false
            }
        }()

        return Button {
            uploadService.post(caption: caption, authToken: auth.token)
            dismiss()
        } label: {
            Text("Post")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isReady ? Color.green : AppColors.purpleAccent.opacity(0.4))
                .clipShape(Capsule())
        }
        .disabled(!isReady)
    }

    // MARK: - Generate Filter Thumbnails

    private func generateFilterThumbnails() async {
        // Wait for thumbnail to be available
        while uploadService.thumbnail == nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard let original = uploadService.thumbnail else { return }

        await Task.detached(priority: .utility) {
            var results: [VideoFilter: UIImage] = [:]
            for filter in VideoFilter.allCases {
                results[filter] = filter.applyToImage(original)
            }
            await MainActor.run {
                filterThumbnails = results
            }
        }.value
    }
}

// MARK: - Video Transferable
struct VideoTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("reel_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Video Camera Recorder (UIImagePickerController)

struct VideoCameraRecorder: UIViewControllerRepresentable {
    let onComplete: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 30
        picker.videoQuality = .typeHigh
        picker.cameraCaptureMode = .video
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onComplete: (URL?) -> Void

        init(onComplete: @escaping (URL?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let videoURL = info[.mediaURL] as? URL {
                // Copy to temp directory to ensure persistence
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("camera_\(UUID().uuidString).mp4")
                try? FileManager.default.copyItem(at: videoURL, to: tempURL)
                onComplete(tempURL)
            } else {
                onComplete(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onComplete(nil)
        }
    }
}

// MARK: - Video Document Picker (Files / iCloud / Drive)

struct VideoDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else { return }

            // Start security-scoped access
            guard sourceURL.startAccessingSecurityScopedResource() else { return }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            // Copy to temp directory
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("files_\(UUID().uuidString).mp4")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                onPick(tempURL)
            } catch {
                // Failed to copy — ignore
            }
        }
    }
}
