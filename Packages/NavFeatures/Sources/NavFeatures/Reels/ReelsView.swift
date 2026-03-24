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
    let music: ReelMusic?
}

// MARK: - Reel Player Pool (Instagram-style, 3-slot circular buffer)
/// Manages 3 AVPlayer instances reused across all reel cards.
/// Pre-buffers the previous, current, and next reel simultaneously.
/// Swiping one card only loads 1 new item — the other two stay buffered.
final class ReelPlayerPool: ObservableObject {
    private static let poolSize = 3
    private let players: [AVPlayer]
    private var loadedURLs: [String?]
    private var loopObservers: [NSObjectProtocol?]
    /// Slot index of the currently active reel (used to gate loop restarts).
    private var activeSlot: Int = 0
    @Published var isMuted: Bool = false

    init() {
        players = (0..<Self.poolSize).map { _ in AVPlayer() }
        loadedURLs = Array(repeating: nil, count: Self.poolSize)
        loopObservers = Array(repeating: nil, count: Self.poolSize)
        for p in players {
            p.isMuted = false
            p.automaticallyWaitsToMinimizeStalling = true
        }
    }

    func toggleMute() {
        isMuted.toggle()
        for p in players { p.isMuted = isMuted }
    }

    /// Call whenever the active reel index changes.
    /// Loads items for [index-1, index, index+1] and plays the current one.
    func activate(currentIndex: Int, urls: [String]) {
        guard !urls.isEmpty else { return }
        activeSlot = currentIndex % Self.poolSize
        let lo = max(0, currentIndex - 1)
        let hi = min(urls.count - 1, currentIndex + 1)

        for idx in lo...hi {
            let slot = idx % Self.poolSize
            let url = urls[idx]
            if loadedURLs[slot] != url {
                loadedURLs[slot] = url
                if let obs = loopObservers[slot] {
                    NotificationCenter.default.removeObserver(obs)
                    loopObservers[slot] = nil
                }
                if let videoURL = AppConfig.resolveMediaURL(url) {
                    let item = AVPlayerItem(url: videoURL)
                    item.preferredForwardBufferDuration = 3
                    players[slot].replaceCurrentItem(with: item)
                    let capturedSlot = slot
                    loopObservers[slot] = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: item,
                        queue: .main
                    ) { [weak self] _ in
                        guard let self, self.activeSlot == capturedSlot else { return }
                        self.players[capturedSlot].seek(to: .zero)
                        self.players[capturedSlot].play()
                    }
                }
            }
        }

        // Play current slot, pause others
        let activeSlots = Set((lo...hi).map { $0 % Self.poolSize })
        for idx in lo...hi {
            let slot = idx % Self.poolSize
            if idx == currentIndex {
                players[slot].seek(to: .zero)
                players[slot].play()
            } else {
                players[slot].pause()
            }
        }
        for slot in 0..<Self.poolSize where !activeSlots.contains(slot) {
            players[slot].pause()
        }
    }

    /// Returns the shared AVPlayer for the given reel index.
    func player(for index: Int) -> AVPlayer { players[index % Self.poolSize] }

    func pauseAll() { players.forEach { $0.pause() } }

    func reset() {
        for slot in 0..<Self.poolSize {
            players[slot].pause()
            players[slot].replaceCurrentItem(with: nil)
            loadedURLs[slot] = nil
            if let obs = loopObservers[slot] {
                NotificationCenter.default.removeObserver(obs)
                loopObservers[slot] = nil
            }
        }
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
        ("play.rectangle.fill", "Discover", 0),
        ("heart.fill", "Likes", 1),
        ("message.fill", "Chat", 2),
        ("magnifyingglass", "Search", 3),
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
                        if tab.tag == 0 {
                            // Already on Discover/Reels, just hide the bar
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
                        .foregroundColor(tab.tag == 0 ? AppColors.primary : .white.opacity(0.7))
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
    @StateObject private var pool = ReelPlayerPool()
    @State private var currentIndex: Int? = 0
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
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                                ReelCard(
                                    reel: binding(for: index),
                                    isActive: index == currentIndex,
                                    player: pool.player(for: index),
                                    isMuted: pool.isMuted,
                                    onMuteToggle: { pool.toggleMute() },
                                    onProfileTap: { handleProfileTap(reel: reels[index]) }
                                )
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentIndex)
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
        .onChange(of: currentIndex) { _, idx in
            pool.activate(currentIndex: idx ?? 0, urls: reels.map { $0.videoUrl })
        }
        .onChange(of: feedScope) { _, _ in
            currentIndex = 0
            pool.reset()
        }
        .onDisappear { pool.pauseAll() }
        .onAppear { pool.activate(currentIndex: currentIndex ?? 0, urls: reels.map { $0.videoUrl }) }
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
                let hls_url: String?; let hls_state: String?
                let thumbnail_url: String?; let duration_sec: Int?
                let caption: String?; let category: String?
                let like_count: Int?; let view_count: Int?
                let engagement_score: Double?
                let creator_name: String?; let creator_age: Int?
                let creator_photo: String?; let creator_verified: Bool?
                let creator_location: String?
                let music: ReelMusic?
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
                         videoUrl: (r.hls_state == "ready" ? r.hls_url : nil) ?? r.video_url ?? "",
                         caption: r.caption ?? "",
                         likes: r.like_count ?? 0, isLiked: false,
                         isVerified: r.creator_verified ?? false, location: r.creator_location ?? "",
                         music: r.music)
                }
            reels = fetched.isEmpty ? filteredDemos : fetched
        } catch {
            if reels.isEmpty {
                reels = filteredDemos
            }
        }
        isLoading = false
        pool.activate(currentIndex: 0, urls: reels.map { $0.videoUrl })
    }

    private var filteredDemos: [Reel] { [] }

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
    @StateObject private var pool = ReelPlayerPool()
    @State private var userReels: [Reel] = []
    @State private var isLoading = true
    @State private var currentIndex: Int? = 0

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
                    GeometryReader { geo in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(userReels.enumerated()), id: \.element.id) { index, reel in
                                    ReelCard(
                                        reel: Binding(
                                            get: { userReels[index] },
                                            set: { userReels[index] = $0 }
                                        ),
                                        isActive: index == currentIndex,
                                        player: pool.player(for: index),
                                        isMuted: pool.isMuted,
                                        onMuteToggle: { pool.toggleMute() },
                                        onProfileTap: nil
                                    )
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .id(index)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $currentIndex)
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
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
                            Text("\((currentIndex ?? 0) + 1)/\(userReels.count)")
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
            .onChange(of: currentIndex) { _, idx in
                pool.activate(currentIndex: idx ?? 0, urls: userReels.map { $0.videoUrl })
            }
            .onDisappear { pool.pauseAll() }
        }
    }

    private func fetchUserReels() async {
        isLoading = true
        do {
            struct ReelItem: Codable {
                let id: Int; let video_url: String?; let caption: String?
                let hls_url: String?; let hls_state: String?
                let like_count: Int?; let view_count: Int?
                let music: ReelMusic?
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
                    videoUrl: (r.hls_state == "ready" ? r.hls_url : nil) ?? r.video_url ?? "",
                    caption: r.caption ?? "",
                    likes: r.like_count ?? 0, isLiked: false,
                    isVerified: false, location: "",
                    music: r.music
                )
            }
        } catch {
            userReels = []
        }
        isLoading = false
        pool.activate(currentIndex: 0, urls: userReels.map { $0.videoUrl })
    }
}

// MARK: - ReelCard
struct ReelCard: View {
    @Binding var reel: Reel
    let isActive: Bool
    let player: AVPlayer          // Injected from ReelPlayerPool
    var isMuted: Bool = false
    var onMuteToggle: (() -> Void)?
    var onProfileTap: (() -> Void)?
    @State private var showHeart = false
    @State private var showMessageSheet = false
    @State private var showLikeCreator = false
    @State private var isPaused = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if !reel.videoUrl.isEmpty, AppConfig.resolveMediaURL(reel.videoUrl) != nil {
                    FullScreenVideoPlayer(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack { Spacer()
                        Image(systemName: "play.circle.fill").font(.system(size: 72)).foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                }

                // Pause indicator
                if isPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 10)
                        .transition(.opacity)
                }

                // Double-tap heart animation
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .shadow(color: .red.opacity(0.6), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }

                // Bottom content: user info (left) + actions (right)
                VStack(spacing: 0) {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 12) {
                        // Left: user info + caption
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                onProfileTap?()
                            } label: {
                                HStack(spacing: 10) {
                                    AsyncImage(url: AppConfig.resolvePhotoURL(reel.userPhoto)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: { Circle().fill(Color.gray.opacity(0.3)) }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(reel.userName)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                            if reel.isVerified {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.blue)
                                            }
                                            Text("• \(reel.userAge)")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        if !reel.location.isEmpty {
                                            HStack(spacing: 3) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 9))
                                                Text(reel.location)
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                }
                            }

                            if !reel.caption.isEmpty {
                                Text(reel.caption)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                            }

                            if let music = reel.music {
                                HStack(spacing: 5) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 11))
                                    Text("\(music.title) — \(music.artist)")
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.3), radius: 3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right: action buttons (Instagram-style vertical stack)
                        VStack(spacing: 22) {
                            // Like
                            reelAction(
                                icon: reel.isLiked ? "heart.fill" : "heart",
                                count: reel.likes,
                                color: reel.isLiked ? .red : .white
                            ) { toggleLike() }

                            // Comment / Message
                            reelAction(icon: "bubble.right", count: nil, color: .white) {
                                showMessageSheet = true
                            }

                            // Share
                            reelAction(icon: "paperplane", count: nil, color: .white) {}

                            // Like Creator (person heart)
                            Button {
                                likeCreator()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.4), radius: 4)
                                }
                            }

                            // Mute / Unmute
                            Button {
                                onMuteToggle?()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.4), radius: 4)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80) // Space for tab bar
                    .background(
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.4), .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .onTapGesture(count: 2) {
            if !reel.isLiked { toggleLike() }
            withAnimation(.spring(response: 0.3)) { showHeart = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { showHeart = false }
            }
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.15)) {
                isPaused.toggle()
            }
            if isPaused {
                player.pause()
            } else {
                player.play()
            }
        }
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
            if active {
                trackView()
                isPaused = false
            } else {
                isPaused = false
            }
        }
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
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                if let count {
                    Text(formatCount(count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }
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
        case .mixingAudio(let p): return "Mixing audio \(Int(p * 100))%"
        case .uploading(let p): return "Uploading \(Int(p * 100))%"
        case .done: return "Upload complete!"
        case .failed: return "Upload failed — tap to retry"
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
            HStack(spacing: 8) {
                if uploadService.canRetry {
                    Button { uploadService.retry() } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.orange)
                    }
                }
                Button { uploadService.dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                }
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
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var hasPickedVideo = false
    @State private var caption = ""
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var uploadError: String?
    @State private var postScope: ReelFeedScope = .global
    @State private var showPremiumGate = false
    @State private var showTrimmer = false
    @State private var pendingVideoURL: URL?
    @State private var isLoadingVideo = false
    @State private var selectedMusic: ReelMusic?
    @State private var showMusicPicker = false
    @State private var musicVolume: Float = 0.5
    @State private var videoPlayer: AVPlayer?
    @State private var musicPlayer: AVPlayer?
    @State private var isPlayingPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if !hasPickedVideo {
                    videoPickerView
                        .overlay {
                            if isLoadingVideo {
                                ZStack {
                                    Color.black.opacity(0.5).ignoresSafeArea()
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(1.2)
                                        Text("Loading video…")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(24)
                                    .background(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
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
                        stopPreview()
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
                    Task {
                        let duration = await videoDuration(for: url)
                        if duration > 30 {
                            pendingVideoURL = url
                            showTrimmer = true
                        } else {
                            uploadService.prepare(localURL: url)
                            uploadService.applyFilter(.original)
                            hasPickedVideo = true
                        }
                    }
                }
            }
            .onChange(of: uploadService.phase) { _, newPhase in
                if case .failed(let message) = newPhase {
                    uploadError = message
                }
            }
            .alert("Upload Failed", isPresented: Binding(
                get: { uploadError != nil },
                set: { if !$0 { uploadError = nil } }
            )) {
                Button("OK") { uploadError = nil }
            } message: {
                Text(uploadError ?? "An unknown error occurred.")
            }
            .fullScreenCover(isPresented: $showTrimmer) {
                if let url = pendingVideoURL {
                    VideoTrimmerView(
                        videoURL: url,
                        onTrimmed: { trimmedURL in
                            showTrimmer = false
                            pendingVideoURL = nil
                            uploadService.prepare(localURL: trimmedURL)
                            uploadService.applyFilter(.original)
                            hasPickedVideo = true
                        },
                        onCancel: {
                            showTrimmer = false
                            pendingVideoURL = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showMusicPicker) {
                MusicSearchView { music in
                    stopPreview()
                    selectedMusic = music
                }
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Duration Helper

    private func videoDuration(for url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
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
                        isLoadingVideo = true
                        defer { isLoadingVideo = false }
                        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                            let duration = await videoDuration(for: movie.url)
                            if duration > 30 {
                                pendingVideoURL = movie.url
                                showTrimmer = true
                            } else {
                                uploadService.prepare(localURL: movie.url)
                                uploadService.applyFilter(.original)
                                hasPickedVideo = true
                            }
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

                Text("Max 30 seconds · Longer videos can be trimmed")
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

                    // Music picker
                    musicPickerRow

                    // Music volume slider
                    if selectedMusic != nil {
                        musicVolumeSlider
                    }

                    // Scope picker (Global / Local)
                    scopePicker
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
                if isPlayingPreview, let player = videoPlayer {
                    // Video playback preview
                    FullScreenVideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .center) {
                            // Tap to stop
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { stopPreview() }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(12)
                        }
                } else if let thumb = uploadService.thumbnail {
                    let filtered = uploadService.selectedFilter.applyToImage(thumb)
                    Image(uiImage: filtered)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .center) {
                            // Play button overlay (only when video is ready)
                            if uploadService.previewVideoURL != nil {
                                Button { playPreview() } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.85))
                                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                                }
                            }
                        }
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

    // MARK: - Preview Playback

    private func playPreview() {
        guard let videoURL = uploadService.previewVideoURL else { return }

        let vPlayer = AVPlayer(url: videoURL)
        vPlayer.volume = 1.0 - musicVolume  // Original audio reduced by music volume
        videoPlayer = vPlayer

        // If music is selected, play it alongside
        if let music = selectedMusic, let previewURLString = music.previewURL,
           let previewURL = URL(string: previewURLString) {
            let mPlayer = AVPlayer(url: previewURL)
            mPlayer.volume = musicVolume
            musicPlayer = mPlayer
        }

        isPlayingPreview = true
        vPlayer.play()
        musicPlayer?.play()

        // Loop video when it ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: vPlayer.currentItem,
            queue: .main
        ) { [weak vPlayer] _ in
            vPlayer?.seek(to: .zero)
            vPlayer?.play()
        }
    }

    private func stopPreview() {
        videoPlayer?.pause()
        musicPlayer?.pause()
        videoPlayer = nil
        musicPlayer = nil
        isPlayingPreview = false
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
            case .mixingAudio(let p):
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
                Text("Mixing audio \(Int(p * 100))%")
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

    // MARK: - Scope Picker

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visibility")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 0) {
                ForEach(ReelFeedScope.allCases, id: \.self) { scope in
                    Button {
                        if scope == .local && !storeKit.isPremium {
                            showPremiumGate = true
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) { postScope = scope }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: scope == .global ? "globe" : "mappin.circle.fill")
                                .font(.system(size: 13))
                            Text(scope.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            if scope == .local && !storeKit.isPremium {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .foregroundColor(postScope == scope ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(postScope == scope ? AppColors.purpleAccent.opacity(0.5) : Color.clear)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(AppColors.darkCard)
            .clipShape(Capsule())
        }
        .fullScreenCover(isPresented: $showPremiumGate) {
            PremiumView()
        }
    }

    // MARK: - Music Picker Row

    private var musicPickerRow: some View {
        Button { showMusicPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.purpleAccent)
                    .frame(width: 36, height: 36)
                    .background(AppColors.purpleAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let music = selectedMusic {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(music.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        stopPreview()
                        selectedMusic = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Add Music")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(12)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Music Volume Slider

    private var musicVolumeSlider: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Slider(value: Binding(
                    get: { Double(musicVolume) },
                    set: { musicVolume = Float($0) }
                ), in: 0...1)
                .tint(AppColors.purpleAccent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack {
                Text("Original")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("Music: \(Int(musicVolume * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.purpleAccent.opacity(0.8))
                Spacer()
                Text("Music")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Post Button

    private var postButton: some View {
        let isReady: Bool = {
            switch uploadService.phase {
            case .readyToPost: return true
            default: return false
            }
        }()

        return Button {
            stopPreview()
            uploadService.post(caption: caption, scope: postScope.rawValue.lowercased(), music: selectedMusic, musicVolume: musicVolume, authToken: auth.token)
            // Dismiss immediately — upload continues in background via the
            // app-level ReelUploadService singleton. Progress shown in MainTabView.
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
            // Prefer move over copy — it's nearly instant (no byte copying) since
            // the received file is a temporary file on the same filesystem.
            do {
                try FileManager.default.moveItem(at: received.file, to: tempURL)
            } catch {
                try FileManager.default.copyItem(at: received.file, to: tempURL)
            }
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
                // Copy to temp directory, preserving the original file extension
                let ext = videoURL.pathExtension.isEmpty ? "mov" : videoURL.pathExtension
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("camera_\(UUID().uuidString).\(ext)")
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

            // Copy to temp directory, preserving the original file extension
            let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("files_\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                onPick(tempURL)
            } catch {
                // Failed to copy — ignore
            }
        }
    }
}
