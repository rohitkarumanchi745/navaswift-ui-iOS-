import SwiftUI

// MARK: - ProfileView
struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var activeSection: ProfileSection = .connections
    @State private var scrollOffset: CGFloat = 0
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showPreferences = false
    @State private var showPremium = false
    @State private var showSignOutAlert = false
    @State private var showVoiceIntro = false
    @State private var showStudentVerification = false
    @State private var animateStats = false
    
    enum ProfileSection: String, CaseIterable {
        case connections = "Connections"
        case activity = "Activity"
    }
    
    // Demo data
    private let likedProfiles: [LikedProfile] = LikedProfile.demos
    
    private let demoMessages: [(id: String, matchId: String, name: String, photo: String, lastMessage: String, timestamp: String, unread: Int, isOnline: Bool)] = [
        ("m1", "match1", "Ananya", "https://i.pravatar.cc/150?img=1", "Hey! How are you?", "2m ago", 2, true),
        ("m2", "match2", "Priya", "https://i.pravatar.cc/150?img=5", "That sounds amazing!", "1h ago", 0, false),
        ("m3", "match3", "Kavya", "https://i.pravatar.cc/150?img=9", "See you there 😊", "3h ago", 1, true),
    ]
    
    private let demoActivities: [(icon: String, text: String, time: String, color: Color)] = [
        ("heart.fill", "Someone liked your profile", "2h ago", .red),
        ("star.fill", "You received a Super Like", "5h ago", .blue),
        ("bolt.fill", "Your profile was boosted", "1d ago", .orange),
        ("person.2.fill", "New match with Priya!", "2d ago", AppColors.primary),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                statsRow
                    .padding(.top, -20)
                
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
        .background(Color(hex: "F8F9FA"))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.spring(response: 0.6).delay(0.3)) {
                animateStats = true
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
        ZStack(alignment: .bottom) {
            // Background
            LinearGradient(
                colors: [AppColors.primary, AppColors.primary.opacity(0.8), Color(hex: "FF8E53")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 300)
            .overlay {
                // Blurred circles for visual interest
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 200)
                    .offset(x: -80, y: -60)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 150)
                    .offset(x: 100, y: 30)
            }
            .clipped()
            
            // Top bar buttons
            VStack {
                HStack {
                    Spacer()
                    
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)
                
                Spacer()
            }
            .frame(height: 300)
            
            // Avatar and info
            VStack(spacing: 12) {
                // Avatar with gradient ring
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary, Color(hex: "FF8E53"), AppColors.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 128, height: 128)
                    
                    AsyncImage(url: URL(string: auth.user?.photos?.first ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    
                    // Verified badge
                    if auth.user?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.secondary)
                            .background(Circle().fill(.white).frame(width: 24, height: 24))
                            .offset(x: 45, y: 45)
                    }
                }
                
                // Name and location
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(auth.user?.name ?? "Your Name")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        if let age = auth.user?.age {
                            Text("\(age)")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(locationManager.city ?? auth.user?.location ?? "Unknown")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
            }
            .offset(y: 50)
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "128", label: "Likes", delay: 0)
            
            Divider()
                .frame(height: 30)
                .background(AppColors.border)
            
            statItem(value: "24", label: "Matches", delay: 0.1)
            
            Divider()
                .frame(height: 30)
                .background(AppColors.border)
            
            statItem(value: "12", label: "Chats", delay: 0.2)
        }
        .padding(.vertical, 16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal, 24)
    }
    
    private func statItem(value: String, label: String, delay: Double) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(animateStats ? 1 : 0.5)
        .opacity(animateStats ? 1 : 0)
    }
    
    // MARK: - Completion Card
    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Complete Your Profile")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text("\(profileCompletion)%")
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "F0F0F0"))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(AppColors.brandGradient)
                        .frame(width: geo.size.width * CGFloat(profileCompletion) / 100, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("Add more details to get 3x more matches!")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Button { showEditProfile = true } label: {
                Text("Complete Now")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(icon: "slider.horizontal.3", label: "Preferences", color: AppColors.secondary) {
                showPreferences = true
            }
            quickActionButton(icon: "mic.fill", label: "Voice Intro", color: Color(hex: "F4A261")) {
                showVoiceIntro = true
            }
            quickActionButton(icon: "graduationcap.fill", label: "Student", color: Color(hex: "D4AF37")) {
                showStudentVerification = true
            }
            quickActionButton(icon: "crown.fill", label: "Premium", color: AppColors.accent) {
                showPremium = true
            }
        }
    }
    
    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(Circle())
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
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
                    VStack(spacing: 8) {
                        Text(section.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(activeSection == section ? AppColors.primary : AppColors.textMuted)
                        
                        Rectangle()
                            .fill(activeSection == section ? AppColors.primary : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Connections Section
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Who Liked You
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Who Liked You")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("See All") {}
                        .font(.subheadline)
                        .foregroundColor(AppColors.primary)
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
            
            // Messages
            VStack(alignment: .leading, spacing: 12) {
                Text("Messages")
                    .font(.headline)
                    .padding(.horizontal, 16)
                
                ForEach(demoMessages, id: \.id) { msg in
                    messageRow(msg)
                }
            }
        }
    }
    
    private func likedProfileCard(_ profile: LikedProfile) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: profile.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 100, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Blur overlay for non-premium
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 130)
                
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(AppColors.primary)
                    .clipShape(Circle())
                    .offset(x: -4, y: 4)
            }
            
            Text(profile.name)
                .font(.caption.bold())
                .foregroundColor(AppColors.textPrimary)
            
            Text("\(profile.age)")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private func messageRow(_ msg: (id: String, matchId: String, name: String, photo: String, lastMessage: String, timestamp: String, unread: Int, isOnline: Bool)) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: msg.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                
                if msg.isOnline {
                    Circle()
                        .fill(AppColors.online)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(msg.name)
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text(msg.timestamp)
                        .font(.caption2)
                        .foregroundColor(AppColors.textMuted)
                }
                
                HStack {
                    Text(msg.lastMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if msg.unread > 0 {
                        Text("\(msg.unread)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activity feed
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                    .padding(.horizontal, 16)
                
                ForEach(demoActivities, id: \.text) { activity in
                    HStack(spacing: 12) {
                        Image(systemName: activity.icon)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(activity.color)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.text)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(activity.time)
                                .font(.caption2)
                                .foregroundColor(AppColors.textMuted)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 16)
            
            // Insights card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Profile Insights")
                        .font(.headline)
                }
                
                Text("Your profile views increased by 23% this week! Adding a voice intro can boost your matches by 40%.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Footer
    private var footerLinks: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 32)
            
            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Privacy & Safety", systemImage: "shield.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Button {
                showSignOutAlert = true
            } label: {
                Label("Sign Out", systemImage: "arrow.right.square")
                    .font(.subheadline)
                    .foregroundColor(AppColors.error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthManager())
            .environmentObject(LocationManager())
    }
}
