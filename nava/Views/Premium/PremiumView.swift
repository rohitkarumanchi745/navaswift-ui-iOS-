import SwiftUI

// MARK: - Plan Type
enum PlanType: String, CaseIterable, Identifiable {
    case boost, daily, weekly, monthly, ultra
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .boost: return "Boost"
        case .daily: return "Day Pass"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .ultra: return "Ultra"
        }
    }
    
    var price: String {
        switch self {
        case .boost: return "$2.99"
        case .daily: return "$4.99"
        case .weekly: return "$9.99"
        case .monthly: return "$19.99"
        case .ultra: return "$49.99"
        }
    }
    
    var duration: String {
        switch self {
        case .boost: return "1 hour"
        case .daily: return "24 hours"
        case .weekly: return "7 days"
        case .monthly: return "30 days"
        case .ultra: return "3 months"
        }
    }
    
    var badge: String? {
        switch self {
        case .monthly: return "POPULAR"
        case .ultra: return "BEST VALUE"
        default: return nil
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .boost: return .red
        case .daily: return .orange
        case .weekly: return Color(hex: "4ECDC4")
        case .monthly: return Color(hex: "D4AF37")
        case .ultra: return Color(hex: "845EC2")
        }
    }
    
    var icon: String {
        switch self {
        case .boost: return "bolt.fill"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .monthly: return "star.fill"
        case .ultra: return "crown.fill"
        }
    }
    
    var features: [String] {
        switch self {
        case .boost:
            return ["Priority in discovery", "See who's viewing you"]
        case .daily:
            return ["Unlimited likes", "See who likes you", "Priority matching"]
        case .weekly:
            return ["All Day Pass features", "Advanced filters", "Read receipts"]
        case .monthly:
            return ["All Weekly features", "Weekly boost included", "5 Super Likes/day", "Undo last swipe"]
        case .ultra:
            return ["All Monthly features", "Priority support", "Exclusive events", "See all likes instantly"]
        }
    }
}

// MARK: - PremiumView
struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: PlanType = .monthly
    @State private var isPurchasing = false
    @State private var studentDiscount: Double = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateIn = false
    
    private let perks: [(icon: String, title: String, description: String)] = [
        ("heart.fill", "Unlimited Likes", "Like as many profiles as you want"),
        ("eye.fill", "See Who Likes You", "Know who's interested before you swipe"),
        ("bolt.fill", "Priority Matching", "Be seen first by potential matches"),
        ("arrow.uturn.left", "Undo Swipes", "Changed your mind? Go back"),
        ("slider.horizontal.3", "Advanced Filters", "Filter by interests, height, and more"),
        ("checkmark.message.fill", "Read Receipts", "Know when your messages are read"),
    ]
    
    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "0F0F0F")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroSection
                        
                        if studentDiscount > 0 {
                            studentBadge
                        }
                        
                        planCards
                        perksGrid
                        selectedPlanFeatures
                        restoreButton
                        termsText
                    }
                    .padding(.bottom, 120)
                }
                
                // Fixed bottom CTA
                bottomCTA
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
            fetchStudentDiscount()
        }
        .alert("Premium", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundColor(Color(hex: "D4AF37"))
                Text("NAVA")
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Invisible spacer for balance
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Upgrade to Premium")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Get more matches, see who likes you, and unlock exclusive features")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 16)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }
    
    // MARK: - Student Badge
    private var studentBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .foregroundColor(Color(hex: "D4AF37"))
            Text("Student discount: \(Int(studentDiscount * 100))% off!")
                .font(.subheadline.bold())
                .foregroundColor(Color(hex: "D4AF37"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "D4AF37").opacity(0.15))
        .clipShape(Capsule())
    }
    
    // MARK: - Plan Cards
    private var planCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PlanType.allCases) { plan in
                    planCard(plan)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func planCard(_ plan: PlanType) -> some View {
        let isSelected = selectedPlan == plan
        
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: 10) {
                // Badge
                if let badge = plan.badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(plan.badgeColor)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 18)
                }
                
                // Icon
                Image(systemName: plan.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : plan.badgeColor)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ?
                        AnyShapeStyle(plan.badgeColor) :
                        AnyShapeStyle(plan.badgeColor.opacity(0.15))
                    )
                    .clipShape(Circle())
                
                Text(plan.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(plan.price)
                    .font(.headline.bold())
                    .foregroundColor(plan.badgeColor)
                
                Text(plan.duration)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 110)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "252525") : Color(hex: "1A1A1A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? plan.badgeColor : Color(hex: "333333"), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
    }
    
    // MARK: - Perks Grid
    private var perksGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Perks")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(perks, id: \.title) { perk in
                    VStack(spacing: 10) {
                        Image(systemName: perk.icon)
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.primary, Color(hex: "FF8E53")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(perk.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text(perk.description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(hex: "1A1A1A"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Selected Plan Features
    private var selectedPlanFeatures: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedPlan.name) includes:")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(selectedPlan.features, id: \.self) { feature in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(hex: "1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Restore Button
    private var restoreButton: some View {
        Button {
            // Restore purchases
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Terms
    private var termsText: some View {
        Text("Subscription auto-renews. Cancel anytime. By subscribing, you agree to our Terms of Service.")
            .font(.caption2)
            .foregroundColor(Color(hex: "666666"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
    
    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack(spacing: 12) {
            Button {
                purchase()
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isPurchasing ? "Processing..." : "Get \(selectedPlan.name) — \(selectedPlan.price)")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, Color(hex: "FF8E53")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isPurchasing)
            
            Button {
                dismiss()
            } label: {
                Text("Maybe later")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(hex: "0F0F0F")
                .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
        )
    }
    
    // MARK: - API
    
    private func fetchStudentDiscount() {
        Task {
            do {
                struct StudentStatus: Codable {
                    let discount_percent: Double?
                }
                let result: StudentStatus = try await APIService.shared.get(path: "/student/status")
                studentDiscount = (result.discount_percent ?? 0) / 100
            } catch {
                // No student discount
            }
        }
    }
    
    private func purchase() {
        isPurchasing = true
        Task {
            do {
                let passType: String
                switch selectedPlan {
                case .boost: passType = "hourly"
                case .daily: passType = "daily"
                case .weekly: passType = "weekly"
                case .monthly: passType = "monthly"
                case .ultra: passType = "ultra"
                }
                
                struct PurchaseResponse: Codable { let success: Bool? }
                let _: PurchaseResponse = try await APIService.shared.post(
                    path: "/location/purchase-pass",
                    body: [
                        "pass_type": passType,
                        "idempotency_key": UUID().uuidString,
                    ]
                )
                alertMessage = "Purchase successful! Enjoy your premium features."
            } catch {
                alertMessage = "Purchase failed. Please try again."
            }
            isPurchasing = false
            showAlert = true
        }
    }
}

#Preview {
    PremiumView()
}
