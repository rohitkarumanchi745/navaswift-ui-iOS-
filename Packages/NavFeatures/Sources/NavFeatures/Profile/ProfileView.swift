import SwiftUI
import NavCore
import NavNetworking
import NavServices

// MARK: - ProfileView
struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var activeSection: ProfileSection = .connections
    @State private var scrollOffset: CGFloat = 0
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showPreferences = false
    @State private var showPremium = false
    @State private var showSignOutAlert = false
    @State private var showVoiceIntro = false
    @State private var showStudentVerification = false
    @State private var showAIInsights = false
    @State private var animateStats = false
    @State private var floatOffset: CGFloat = 0

    enum ProfileSection: String, CaseIterable {
        case connections = "Connections"
        case activity = "Activity"
    }

    // Live data from backend
    @State private var likedProfiles: [LikedProfile] = []
    @State private var recentMatches: [MatchProfile] = []
    @State private var statsLikes = 0
    @State private var statsMatches = 0
    @State private var statsChats = 0
    @State private var isLoadingStats = true
    @State private var profileError: String?

    var body: some View {
        ZStack {
            // Dark gradient background matching landing/login
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
                    statsRow
                        .padding(.top, 4)

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
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    sectionToggle
                        .padding(.top, 24)

                    if activeSection == .connections {
                        connectionsSection
                    } else {
                        activitySection
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
        .sheet(isPresented: $showAIInsights) {
            NavigationStack { AIInsightsView() }
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
            // Top bar with settings/edit
            HStack {
                Text("Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                Button { showEditProfile = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // Profile photo + name
            VStack(spacing: 16) {
                ZStack {
                    // Gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "9B7FCA"), Color(hex: "7B68AE"), Color(hex: "A8D8EA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 110, height: 110)

                    AsyncImage(url: AppConfig.resolvePhotoURL(auth.user?.photos?.first)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())

                    if auth.user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.verified)
                            .background(Circle().fill(Color(hex: "1A1B2E")).padding(-3))
                            .offset(x: 38, y: 38)
                    }
                }

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(auth.user?.name ?? "Your Name")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        if let age = auth.user?.age {
                            Text("\(age)")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                        Text(locationManager.city.isEmpty ? (auth.user?.location ?? "Unknown") : locationManager.city)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(statsLikes)", label: "Likes", icon: "heart.fill", color: Color(hex: "C9A0DC"))
            statCard(value: "\(statsMatches)", label: "Matches", icon: "sparkles", color: Color(hex: "A8D8EA"))
            statCard(value: "\(statsChats)", label: "Chats", icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "98D4BB"))
        }
        .padding(.horizontal, 20)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(animateStats ? 1 : 0.8)
        .opacity(animateStats ? 1 : 0)
    }

    // MARK: - Completion Card
    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "B8A9D4"))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: "B8A9D4").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete Your Profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Get 3x more matches")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text("\(profileCompletion)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "C9A0DC"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: "7B68AE"), Color(hex: "9B7FCA")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(profileCompletion) / 100, height: 6)
                }
            }
            .frame(height: 6)

            Button { showEditProfile = true } label: {
                Text("Complete Now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                quickActionTile(
                    icon: "slider.horizontal.3",
                    label: "Preferences",
                    subtitle: "Dating filters",
                    color: Color(hex: "A8D8EA"),
                    bgColor: Color(hex: "A8D8EA").opacity(0.15)
                ) { showPreferences = true }

                quickActionTile(
                    icon: "waveform.and.magnifyingglass",
                    label: "AI Insights",
                    subtitle: "Smart analysis",
                    color: Color(hex: "C9A0DC"),
                    bgColor: Color(hex: "C9A0DC").opacity(0.15)
                ) { showAIInsights = true }
            }

            HStack(spacing: 12) {
                quickActionTile(
                    icon: "waveform",
                    label: "Voice Intro",
                    subtitle: "Record now",
                    color: Color(hex: "D4A5C9"),
                    bgColor: Color(hex: "D4A5C9").opacity(0.15)
                ) { showVoiceIntro = true }

                quickActionTile(
                    icon: "building.columns.fill",
                    label: "Student",
                    subtitle: "Verify status",
                    color: Color(hex: "B8C9A3"),
                    bgColor: Color(hex: "B8C9A3").opacity(0.15)
                ) { showStudentVerification = true }
            }

            if !storeKit.isPremium {
                Button { showPremium = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "D4C5A0"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Unlimited likes, see who liked you & more")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func quickActionTile(icon: String, label: String, subtitle: String, color: Color, bgColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(bgColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Section Toggle
    private var sectionToggle: some View {
        HStack(spacing: 4) {
            ForEach(ProfileSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(activeSection == section ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(activeSection == section ? Color(hex: "6C5CE7") : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Connections Section
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Who Liked You")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("See All") {}
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "9B7FCA"))
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(likedProfiles) { profile in
                            likedProfileCard(profile)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                Text("Messages")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                if recentMatches.isEmpty {
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                } else {
                    ForEach(recentMatches.prefix(3)) { match in
                        matchMessageRow(match)
                    }
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
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.1))
                }
                .frame(width: 100, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    .frame(width: 100, height: 130)

                Image(systemName: "lock.fill")
                    .font(.caption).foregroundColor(.white)
                    .padding(4).background(Color(hex: "9B7FCA")).clipShape(Circle())
                    .offset(x: -4, y: 4)
            }
            Text(profile.name).font(.caption.bold()).foregroundColor(.white)
            Text("\(profile.age)").font(.caption2).foregroundColor(.white.opacity(0.5))
        }
    }

    private func matchMessageRow(_ match: MatchProfile) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(match.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.white.opacity(0.1))
                }
                .frame(width: 52, height: 52).clipShape(Circle())

                if match.isOnline {
                    Circle().fill(AppColors.online).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(hex: "1A1B2E"), lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(match.name).font(.subheadline.bold()).foregroundColor(.white)
                    Spacer()
                    Text(match.timestamp ?? "").font(.caption2).foregroundColor(.white.opacity(0.4))
                }
                HStack {
                    Text(match.lastMessage ?? "Say hi!").font(.caption)
                        .foregroundColor(.white.opacity(0.6)).lineLimit(1)
                    Spacer()
                    if match.unreadCount > 0 {
                        Text("\(match.unreadCount)").font(.caption2.bold()).foregroundColor(.white)
                            .frame(width: 20, height: 20).background(Color(hex: "9B7FCA")).clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                if recentMatches.isEmpty && likedProfiles.isEmpty {
                    Text("No activity yet. Start swiping to see activity here!")
                        .font(.subheadline).foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 16).padding(.top, 8)
                } else {
                    ForEach(recentMatches.prefix(3)) { match in
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill").font(.body).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color(hex: "9B7FCA")).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Matched with \(match.name)").font(.subheadline).foregroundColor(.white)
                                Text(match.timestamp ?? "").font(.caption2).foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 4)
                    }

                    if statsLikes > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill").font(.body).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(.red).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(statsLikes) people liked your profile").font(.subheadline).foregroundColor(.white)
                                Text("recently").font(.caption2).foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 4)
                    }
                }
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                    Text("Profile Insights")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Text("Your profile views increased by 23% this week! Adding a voice intro can boost your matches by 40%.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.6)).lineSpacing(4)
            }
            .padding(16)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Data Loading
    private func loadProfileData() async {
        isLoadingStats = true
        do {
            let query = """
            query {
                matches {
                    id
                    partner { id name age photos }
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
                        convos.append(MatchProfile(
                            id: "\(partner["id"] ?? "")",
                            matchId: "\(m["id"] ?? "")",
                            name: partner["name"] as? String ?? "",
                            age: partner["age"] as? Int ?? 0,
                            photo: photos?.first ?? "",
                            lastMessage: nil,
                            timestamp: ts,
                            unreadCount: 0,
                            isOnline: false,
                            isMutual: true
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
            profileError = error.localizedDescription
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

    // MARK: - Footer
    private var footerLinks: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: PrivacyPolicyView()) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 32)
                    Text("Privacy & Safety")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider().background(.white.opacity(0.1)).padding(.leading, 60)

            Button { showSignOutAlert = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "FF6B6B"))
                        .frame(width: 32)
                    Text("Sign Out")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "FF6B6B"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
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
