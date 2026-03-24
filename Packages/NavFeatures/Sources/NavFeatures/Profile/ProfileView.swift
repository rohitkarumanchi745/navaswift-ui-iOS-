import SwiftUI
import AVFoundation
import NavCore
import NavNetworking
import NavServices

// MARK: - My Reel Item
private struct MyReelItem: Identifiable {
    let id: String
    let videoUrl: String
    let caption: String
    let likeCount: Int
    let viewCount: Int
    let thumbnail: UIImage?
}

// MARK: - ProfileView
struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var uploadService: ReelUploadService
    @State private var activeSection: ProfileSection = .connections
    @State private var scrollOffset: CGFloat = 0
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showPreferences = false
    @State private var showPremium = false
    @State private var showSignOutAlert = false
    @State private var showVoiceIntro = false
    @State private var showStudentVerification = false
    @State private var showAlumniVerification = false
    @State private var showProfessionalVerification = false
    @State private var showAIInsights = false
    @State private var showInvite = false
    @State private var animateStats = false
    @State private var floatOffset: CGFloat = 0
    @State private var ringRotation: Double = 0

    enum ProfileSection: String, CaseIterable {
        case connections = "Connections"
        case activity = "Activity"
        case myReels = "My Reels"
    }

    // Live data from backend
    @State private var likedProfiles: [LikedProfile] = []
    @State private var recentMatches: [MatchProfile] = []
    @State private var statsLikes = 0
    @State private var statsMatches = 0
    @State private var statsChats = 0
    @State private var isLoadingStats = true
    @State private var profileError: String?

    // My Reels
    @State private var myReels: [MyReelItem] = []
    @State private var isLoadingReels = false
    @State private var showUploadReel = false
    @State private var selectedReelIndex: Int = 0
    @State private var showReelPlayer = false
    @State private var showReelInbox = false

    // Reel Activity
    @State private var reelActivity: [ReelActivityItem] = []
    @State private var reelTotalLikes = 0
    @State private var reelTotalViews = 0
    @State private var reelTotalMessages = 0
    @State private var isLoadingReelActivity = false

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
                .fill(Color(hex: "FF5864").opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 120, y: -300 + floatOffset)

            Circle()
                .fill(Color(hex: "6A4C93").opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -100, y: 200 - floatOffset)

            ScrollView {
                VStack(spacing: 0) {
                    heroSection

                    // Photo gallery
                    if let photos = auth.user?.photos, photos.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { _, photoPath in
                                    AsyncImage(url: AppConfig.resolvePhotoURL(photoPath)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(.white.opacity(0.06))
                                            .overlay(
                                                ProgressView()
                                                    .tint(.white.opacity(0.3))
                                            )
                                    }
                                    .frame(width: 100, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)
                    }

                    statsRow
                        .padding(.top, 12)

                    if let error = profileError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.warning)
                            Text("Could not load stats: \(error)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Button("Retry") {
                                profileError = nil
                                Task { await loadProfileData() }
                            }
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "9B7FCA"))
                        }
                        .padding(12)
                        .background(AppColors.warning.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    if profileCompletion < 100 {
                        completionCard
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    quickActions
                        .padding(.top, 20)

                    sectionToggle
                        .padding(.top, 24)

                    switch activeSection {
                    case .connections:
                        connectionsSection
                    case .activity:
                        activitySection
                    case .myReels:
                        myReelsSection
                    }

                    footerLinks
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .task { await loadProfileData() }
        .onAppear {
            withAnimation(.spring(response: 0.6).delay(0.3)) {
                animateStats = true
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = 20
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                auth.logout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack { EditProfileView() }
        }
        .sheet(isPresented: $showPreferences) {
            NavigationStack { PreferencesView() }
        }
        .fullScreenCover(isPresented: $showPremium) {
            PremiumView()
        }
        .sheet(isPresented: $showVoiceIntro) {
            NavigationStack { VoiceIntroView() }
        }
        .sheet(isPresented: $showStudentVerification) {
            NavigationStack { StudentVerificationView() }
        }
        .sheet(isPresented: $showAlumniVerification) {
            NavigationStack { AlumniVerificationView() }
        }
        .sheet(isPresented: $showProfessionalVerification) {
            NavigationStack { ProfessionalVerificationView() }
        }
        .sheet(isPresented: $showAIInsights) {
            NavigationStack { AIInsightsView() }
        }
        .sheet(isPresented: $showInvite) {
            NavigationStack { InviteView() }
        }
        .sheet(isPresented: $showUploadReel) {
            UploadReelView()
                .environmentObject(uploadService)
        }
        .sheet(isPresented: $showReelInbox) {
            NavigationStack {
                ReelInboxView()
            }
        }
        .fullScreenCover(isPresented: $showReelPlayer) {
            MyReelsPlayerView(
                reels: myReels,
                startIndex: selectedReelIndex,
                userName: auth.user?.name ?? "You",
                userPhoto: auth.user?.photos?.first ?? ""
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: ReelUploadService.didFinishUploadNotification)) { _ in
            Task {
                await fetchMyReels()
                await fetchReelActivity()
            }
        }
    }

    // MARK: - Profile Completion
    private var profileCompletion: Int {
        guard let user = auth.user else { return 0 }
        var score = 0
        let total = 8
        if !(user.name ?? "").isEmpty { score += 1 }
        if !(user.gender ?? "").isEmpty { score += 1 }
        if !(user.bio ?? "").isEmpty { score += 1 }
        if !(user.photos ?? []).isEmpty { score += 1 }
        if !(user.interests ?? []).isEmpty { score += 1 }
        if !(user.languages ?? []).isEmpty { score += 1 }
        if user.heightCm != nil { score += 1 }
        if !(user.lookingFor ?? "").isEmpty { score += 1 }
        return Int((Double(score) / Double(total)) * 100)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 8) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)

            // Profile photo + name
            VStack(spacing: 16) {
                // Photo with animated gradient ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color(hex: "9B7FCA"),
                                    Color(hex: "FF8A9E"),
                                    Color(hex: "A8D8EA"),
                                    Color(hex: "C9A0DC"),
                                    Color(hex: "9B7FCA")
                                ],
                                center: .center
                            )
                        )
                        .frame(width: 118, height: 118)
                        .blur(radius: 8)
                        .opacity(0.5)
                        .rotationEffect(.degrees(ringRotation))

                    // Ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "9B7FCA"),
                                    Color(hex: "FF8A9E"),
                                    Color(hex: "A8D8EA"),
                                    Color(hex: "C9A0DC"),
                                    Color(hex: "9B7FCA")
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(ringRotation))

                    // Photo
                    AsyncImage(url: AppConfig.resolvePhotoURL(auth.user?.photos?.first)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            Circle().fill(Color(hex: "2D1B4E"))
                            Image(systemName: "person.fill")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "9B7FCA"), Color(hex: "C9A0DC")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .frame(width: 102, height: 102)
                    .clipShape(Circle())

                    // Verified badge
                    if auth.user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.verified)
                            .background(Circle().fill(Color(hex: "1A1B2E")).padding(-4))
                            .offset(x: 38, y: 38)
                    }

                    // Edit overlay
                    Button { showEditProfile = true } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: "9B7FCA"))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(hex: "1A1B2E"), lineWidth: 2))
                    }
                    .offset(x: -38, y: 38)
                }

                // Name + Age
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(auth.user?.name ?? "Your Name")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        if let age = auth.user?.age {
                            Text("\(age)")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // University + study badges
                    if let uni = auth.user?.university, !uni.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "C9A0DC"))
                            Text(uni)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "C9A0DC"))
                            if let study = auth.user?.study, !study.isEmpty {
                                Text("·")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "C9A0DC").opacity(0.5))
                                Text(study)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "C9A0DC").opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "9B7FCA").opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Location
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text(locationManager.city.isEmpty ? (auth.user?.location ?? "Set your location") : locationManager.city)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))

                    // Bio snippet
                    if let bio = auth.user?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                            .padding(.top, 2)
                    }

                    // Verification badges
                    verificationBadgesRow
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Verification Badges
    private var verificationBadgesRow: some View {
        HStack(spacing: 8) {
            if auth.user?.isVerified == true {
                badgePill(icon: "checkmark.seal.fill", text: "Verified", color: AppColors.verified)
            }
            if auth.user?.isAlumniVerified == true {
                badgePill(icon: "building.columns.fill", text: "Alumni", color: Color(hex: "4A90D9"))
            }
            if auth.user?.graduationYear != nil && auth.user?.isAlumniVerified != true {
                badgePill(icon: "graduationcap.fill", text: "Alumni", color: Color(hex: "7ED4A6").opacity(0.7))
            }
        }
    }

    private func badgePill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(statsLikes)", label: "Likes", icon: "heart.fill", color: Color(hex: "FF8A9E"))
            statCard(value: "\(statsMatches)", label: "Matches", icon: "person.2.fill", color: Color(hex: "C9A0DC"))
            statCard(value: "\(statsChats)", label: "Chats", icon: "bubble.left.fill", color: Color(hex: "7BB3FF"))
        }
        .padding(.horizontal, 20)
        .scaleEffect(animateStats ? 1 : 0.9)
        .opacity(animateStats ? 1 : 0)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Completion Card
    private var completionCard: some View {
        Button { showEditProfile = true } label: {
            HStack(spacing: 14) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(profileCompletion) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "9B7FCA"), Color(hex: "C9A0DC")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(profileCompletion)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "C9A0DC"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Complete your profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Get up to 3x more matches")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(14)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        VStack(spacing: 16) {
            // Premium banner
            if !storeKit.isPremium {
                Button { showPremium = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "FFD700"), Color(hex: "F0C27F")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black.opacity(0.8))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("See who liked you, unlimited likes & more")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "FFD700").opacity(0.4), Color(hex: "FFD700").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
            }

            // Verification group
            actionGroup(title: "Verification", items: [
                ActionItem(icon: "graduationcap.fill", label: "Student Verification", color: Color(hex: "7ED4A6"),
                           verified: auth.user?.isVerified == true) { showStudentVerification = true },
                ActionItem(icon: "building.columns.fill", label: "Alumni Verification", color: Color(hex: "4A90D9"),
                           verified: auth.user?.isAlumniVerified == true) { showAlumniVerification = true },
                ActionItem(icon: "briefcase.fill", label: "Professional Verification", color: Color(hex: "FFB347"),
                           verified: false) { showProfessionalVerification = true },
            ])

            // Features group
            actionGroup(title: "Features", items: [
                ActionItem(icon: "slider.horizontal.3", label: "Preferences", color: Color(hex: "7BB3FF"),
                           verified: false) { showPreferences = true },
                ActionItem(icon: "sparkle.magnifyingglass", label: "AI Insights", color: Color(hex: "C9A0DC"),
                           verified: false) { showAIInsights = true },
                ActionItem(icon: "mic.fill", label: "Voice Intro", color: Color(hex: "FF8A9E"),
                           verified: false) { showVoiceIntro = true },
                ActionItem(icon: "qrcode", label: "Invite Friends", color: Color(hex: "6C5CE7"),
                           verified: false) { showInvite = true },
            ])
        }
        .padding(.horizontal, 20)
    }

    private struct ActionItem {
        let icon: String
        let label: String
        let color: Color
        let verified: Bool
        let action: () -> Void
    }

    private func actionGroup(title: String, items: [ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1)
                .padding(.leading, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button(action: item.action) {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(item.color)
                                .frame(width: 34, height: 34)
                                .background(item.color.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 9))

                            Text(item.label)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            if item.verified {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "4ECDC4"))
                                    Text("Verified")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color(hex: "4ECDC4"))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "4ECDC4").opacity(0.12))
                                .clipShape(Capsule())
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 62)
                    }
                }
            }
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Section Toggle
    private var sectionToggle: some View {
        HStack(spacing: 0) {
            ForEach(ProfileSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(activeSection == section ? .white : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(activeSection == section ? .white.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(3)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Connections Section
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Who Liked You
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Who Liked You")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "9B7FCA"))
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(likedProfiles) { profile in
                            likedProfileCard(profile)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)

            // Messages
            VStack(alignment: .leading, spacing: 12) {
                Text("Messages")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                if recentMatches.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No conversations yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recentMatches.prefix(3)) { match in
                            matchMessageRow(match)
                        }
                    }
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func likedProfileCard(_ profile: LikedProfile) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08))
                }
                .frame(width: 80, height: 105)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    .frame(width: 80, height: 105)

                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color(hex: "9B7FCA"))
                    .clipShape(Circle())
                    .offset(x: -4, y: 4)
            }
            Text(profile.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func matchMessageRow(_ match: MatchProfile) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(match.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.white.opacity(0.08))
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())

                if match.isOnline {
                    Circle()
                        .fill(AppColors.online)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(hex: "1A1B2E"), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(match.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(match.timestamp ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                Text(match.lastMessage ?? "Say hi!")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            if match.unreadCount > 0 {
                Text("\(match.unreadCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: "9B7FCA"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Recent Activity
            VStack(alignment: .leading, spacing: 14) {
                Text("Recent Activity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                if recentMatches.isEmpty && likedProfiles.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.2))
                        Text("No activity yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(recentMatches.prefix(3)) { match in
                            HStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "C9A0DC"))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "C9A0DC").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Matched with \(match.name)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(match.timestamp ?? "")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }

                        if statsLikes > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "FF8A9E"))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "FF8A9E").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(statsLikes) people liked your profile")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("recently")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)

            // Reel Engagement Summary
            if reelTotalLikes > 0 || reelTotalViews > 0 || reelTotalMessages > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reel Engagement")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        if reelTotalLikes > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "FF8A9E"))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "FF8A9E").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(reelTotalLikes) likes on your reels")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("total")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }

                        if reelTotalMessages > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "C9A0DC"))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "C9A0DC").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(reelTotalMessages) messages on your reels")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("total")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                                Button { showReelInbox = true } label: {
                                    Text("View")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "C9A0DC"))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }

                        if reelTotalViews > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "7BB3FF"))
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "7BB3FF").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(reelTotalViews) views on your reels")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("total")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }
            }

            // Insights
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "FFD700"))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: "FFD700").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Insight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Adding a voice intro can boost your matches by 40%.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(3)
                }
            }
            .padding(14)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - My Reels Section
    private var myReelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Reels")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()

                Button { showReelInbox = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Inbox")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "7BB3FF"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "7BB3FF").opacity(0.15))
                    .clipShape(Capsule())
                }

                Button { showUploadReel = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "C9A0DC"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "C9A0DC").opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            // Upload progress pill
            if uploadService.phase != .idle {
                ReelUploadProgressPill(uploadService: uploadService)
                    .padding(.horizontal, 20)
            }

            if isLoadingReels {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .padding(.vertical, 40)
            } else if myReels.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.15))
                    Text("No reels yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Share a moment with the community")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.25))
                    Button { showUploadReel = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 14))
                            Text("Upload Reel")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "9B7FCA"))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ]
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(myReels.enumerated()), id: \.element.id) { index, reel in
                        Button {
                            selectedReelIndex = index
                            showReelPlayer = true
                        } label: {
                            myReelThumbnail(reel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Reel engagement stats
            if !myReels.isEmpty {
                reelEngagementStats
            }

            // Recent reel activity
            if !myReels.isEmpty {
                reelActivitySection
            }
        }
        .padding(.top, 16)
        .task {
            await fetchMyReels()
            await fetchReelActivity()
        }
    }

    // MARK: - Reel Engagement Stats

    private var reelEngagementStats: some View {
        HStack(spacing: 0) {
            reelStatItem(icon: "heart.fill", color: "FF8A9E", value: reelTotalLikes, label: "Likes")
            reelStatItem(icon: "eye.fill", color: "7BB3FF", value: reelTotalViews, label: "Views")
            reelStatItem(icon: "bubble.left.fill", color: "C9A0DC", value: reelTotalMessages, label: "Messages")
        }
        .padding(.vertical, 14)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func reelStatItem(icon: String, color: String, value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: color))
            Text(formatCompact(value))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reel Activity Section (inside My Reels)

    private var reelActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reel Activity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if !reelActivity.isEmpty {
                    NavigationLink {
                        ReelActivityListView(initialActivities: reelActivity)
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "9B7FCA"))
                    }
                }
            }
            .padding(.horizontal, 20)

            if isLoadingReelActivity {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .padding(.vertical, 20)
            } else if reelActivity.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No activity yet on your reels")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(reelActivity.prefix(5)) { item in
                        reelActivityRow(item)

                        if item.id != reelActivity.prefix(5).last?.id {
                            Rectangle()
                                .fill(.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }

    private func reelActivityRow(_ item: ReelActivityItem) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(item.actorPhoto)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.white.opacity(0.08))
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())

                Image(systemName: item.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color(hex: item.iconColor))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "1A1B2E"), lineWidth: 2))
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.actorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    +
                    Text(" \(item.activityDescription)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()
                }

                if let caption = item.reelCaption, !caption.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 9))
                        Text(caption)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.3))
                }

                Text(relativeTimeForActivity(item.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func relativeTimeForActivity(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: dateStr) else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return "\(Int(interval / 604800))w ago"
    }

    private func myReelThumbnail(_ reel: MyReelItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let thumbnail = reel.thumbnail {
                GeometryReader { geo in
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                LinearGradient(
                    colors: [Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                if reel.viewCount > 0 {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text(formatCompact(reel.viewCount))
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.5))
            .clipShape(Capsule())
            .padding(6)
        }
        .overlay(alignment: .bottomTrailing) {
            if reel.likeCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                    Text(formatCompact(reel.likeCount))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(6)
            }
        }
    }

    private func formatCompact(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }

    // MARK: - Data Loading

    private func fetchMyReels() async {
        guard let userId = auth.user?.id, !userId.isEmpty else { return }
        isLoadingReels = true
        do {
            struct ReelItem: Codable {
                let id: Int; let video_url: String?; let caption: String?
                let like_count: Int?; let view_count: Int?; let thumbnail_url: String?
            }
            struct ReelResponse: Codable { let reels: [ReelItem] }
            let response: ReelResponse = try await APIService.shared.get(
                path: "/reels/user/\(userId)"
            )
            var items: [MyReelItem] = []
            for r in response.reels {
                let thumb = await generateThumbnail(from: r.video_url, fallback: r.thumbnail_url)
                items.append(MyReelItem(
                    id: "\(r.id)",
                    videoUrl: r.video_url ?? "",
                    caption: r.caption ?? "",
                    likeCount: r.like_count ?? 0,
                    viewCount: r.view_count ?? 0,
                    thumbnail: thumb
                ))
            }
            myReels = items
        } catch {
            // No demo fallback — empty state is fine for own reels
        }
        isLoadingReels = false
    }

    private func fetchReelActivity() async {
        isLoadingReelActivity = true
        do {
            let response: ReelActivityResponse = try await APIService.shared.get(
                path: "/reels/activity?limit=20"
            )
            reelActivity = response.activities
            reelTotalLikes = response.totalLikes ?? myReels.reduce(0) { $0 + $1.likeCount }
            reelTotalViews = response.totalViews ?? myReels.reduce(0) { $0 + $1.viewCount }
            reelTotalMessages = response.totalMessages ?? 0

            LocalCache.shared.save(response, forKey: .reelActivity)
        } catch {
            // Try cached data
            if let cached = LocalCache.shared.load(ReelActivityResponse.self, forKey: .reelActivity) {
                reelActivity = cached.activities
                reelTotalLikes = cached.totalLikes ?? 0
                reelTotalViews = cached.totalViews ?? 0
                reelTotalMessages = cached.totalMessages ?? 0
            } else {
                // Compute totals from myReels data at minimum
                reelTotalLikes = myReels.reduce(0) { $0 + $1.likeCount }
                reelTotalViews = myReels.reduce(0) { $0 + $1.viewCount }
                reelActivity = []
            }
        }
        isLoadingReelActivity = false
    }

    private func generateThumbnail(from videoUrl: String?, fallback thumbnailUrl: String?) async -> UIImage? {
        // Try thumbnail URL first
        if let url = AppConfig.resolveMediaURL(thumbnailUrl) {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        // Generate from video
        guard let url = AppConfig.resolveMediaURL(videoUrl) else { return nil }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 800)
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func loadProfileData() async {
        isLoadingStats = true
        do {
            let query = """
            query {
                matches {
                    id
                    partner { id name age photos isOnline lastSeen }
                    isMutual
                    matchedAt
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            if let matchList = result["matches"] as? [[String: Any]] {
                var likes: [LikedProfile] = []
                var convos: [MatchProfile] = []

                for m in matchList {
                    let partner = m["partner"] as? [String: Any] ?? [:]
                    let photos = partner["photos"] as? [String]
                    let isMutual = m["isMutual"] as? Bool ?? false
                    let ts = formatTimestamp(m["matchedAt"] as? String)

                    if isMutual {
                        let online = partner["isOnline"] as? Bool ?? false
                        let lastSeenDate = parseISO(partner["lastSeen"] as? String)
                        convos.append(MatchProfile(
                            id: "\(partner["id"] ?? "")",
                            matchId: "\(m["id"] ?? "")",
                            name: partner["name"] as? String ?? "",
                            age: partner["age"] as? Int ?? 0,
                            photo: photos?.first ?? "",
                            lastMessage: nil,
                            timestamp: ts,
                            unreadCount: 0,
                            isOnline: online,
                            isMutual: true,
                            lastSeen: lastSeenDate
                        ))
                    } else {
                        likes.append(LikedProfile(
                            id: "\(partner["id"] ?? "")",
                            name: partner["name"] as? String ?? "",
                            age: partner["age"] as? Int ?? 0,
                            photo: photos?.first ?? "",
                            type: .swipe,
                            likedAt: ts ?? ""
                        ))
                    }
                }

                likedProfiles = likes
                recentMatches = convos
                statsLikes = likes.count
                statsMatches = matchList.count
                statsChats = convos.count
            }
        } catch {
            if likedProfiles.isEmpty && recentMatches.isEmpty {
                likedProfiles = []
                recentMatches = []
                statsLikes = likedProfiles.count
                statsMatches = likedProfiles.count + recentMatches.count
                statsChats = recentMatches.count
            }
        }
        isLoadingStats = false
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

    private func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    // MARK: - Footer
    private var footerLinks: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: PrivacyPolicyView()) {
                HStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    Text("Privacy & Safety")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.leading, 62)

            Button { showSignOutAlert = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "FF6B6B").opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: "FF6B6B").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "FF6B6B").opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - My Reels Player

private struct MyReelsPlayerView: View {
    let userName: String
    let userPhoto: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pool = ReelPlayerPool()
    @State private var currentIndex: Int?
    @State private var playerReels: [Reel]

    init(reels: [MyReelItem], startIndex: Int, userName: String, userPhoto: String) {
        self.userName = userName
        self.userPhoto = userPhoto
        _currentIndex = State(initialValue: startIndex)
        _playerReels = State(initialValue: reels.map { item in
            Reel(
                id: item.id,
                userId: "",
                userName: userName,
                userAge: 0,
                userPhoto: userPhoto,
                videoUrl: item.videoUrl,
                caption: item.caption,
                likes: item.likeCount,
                isLiked: false,
                isVerified: false,
                location: "",
                music: nil
            )
        })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playerReels.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No reels to play")
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(playerReels.enumerated()), id: \.element.id) { index, _ in
                                ReelCard(
                                    reel: Binding(
                                        get: { playerReels[index] },
                                        set: { playerReels[index] = $0 }
                                    ),
                                    isActive: index == currentIndex,
                                    player: pool.player(for: index),
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

            // Header overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Text("My Reels")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    if !playerReels.isEmpty {
                        Text("\((currentIndex ?? 0) + 1)/\(playerReels.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
        }
        .task { pool.activate(currentIndex: currentIndex ?? 0, urls: playerReels.map { $0.videoUrl }) }
        .onChange(of: currentIndex) { _, idx in
            pool.activate(currentIndex: idx ?? 0, urls: playerReels.map { $0.videoUrl })
        }
        .onDisappear { pool.pauseAll() }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthManager())
            .environmentObject(LocationManager())
            .environmentObject(StoreKitManager())
    }
}
