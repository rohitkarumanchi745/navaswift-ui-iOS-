import SwiftUI
import StoreKit
import NavCore
import NavNetworking
import NavServices

// MARK: - Fallback Plan (when StoreKit products unavailable)

private struct FallbackPlan: Identifiable {
    let id: String
    let tier: PremiumTier
    let price: String
    let period: String

    static let all: [FallbackPlan] = [
        FallbackPlan(id: StoreProductID.goldMonthly.rawValue, tier: .gold, price: "$9.99", period: "/mo"),
        FallbackPlan(id: StoreProductID.platinumMonthly.rawValue, tier: .platinum, price: "$19.99", period: "/mo"),
        FallbackPlan(id: StoreProductID.ultraMonthly.rawValue, tier: .ultra, price: "$29.99", period: "/mo"),
    ]
}

struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var selectedProduct: Product?
    @State private var selectedFallback: FallbackPlan?
    @State private var isStudentVerified = false
    @State private var animateIn = false
    @State private var showError = false
    @State private var errorMessage = ""

    private struct PerkRow: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let gold: Bool
        let platinum: Bool
        let ultra: Bool
    }

    private let perkRows: [PerkRow] = [
        PerkRow(icon: "heart.fill",              title: "Unlimited Likes",      gold: true,  platinum: true,  ultra: true),
        PerkRow(icon: "eye.fill",                title: "See Who Likes You",    gold: true,  platinum: true,  ultra: true),
        PerkRow(icon: "star.fill",               title: "5 Super Likes / Day",  gold: true,  platinum: true,  ultra: true),
        PerkRow(icon: "slider.horizontal.3",     title: "Advanced Filters",     gold: true,  platinum: true,  ultra: true),
        PerkRow(icon: "bolt.fill",               title: "1 Free Boost / Month", gold: true,  platinum: true,  ultra: true),
        PerkRow(icon: "arrow.uturn.left",        title: "Undo Last Swipe",      gold: false, platinum: true,  ultra: true),
        PerkRow(icon: "sparkles",                title: "Priority Matching",    gold: false, platinum: true,  ultra: true),
        PerkRow(icon: "checkmark.message.fill",  title: "Read Receipts",        gold: false, platinum: true,  ultra: true),
        PerkRow(icon: "flame.fill",              title: "Weekly Boost",         gold: false, platinum: true,  ultra: true),
        PerkRow(icon: "star.circle.fill",        title: "Unlimited Super Likes",gold: false, platinum: false, ultra: true),
        PerkRow(icon: "eyes",                    title: "See All Likes Instantly",gold: false, platinum: false, ultra: true),
        PerkRow(icon: "headphones.circle.fill",  title: "Priority Support",     gold: false, platinum: false, ultra: true),
        PerkRow(icon: "party.popper.fill",       title: "Exclusive Events",     gold: false, platinum: false, ultra: true),
    ]

    var body: some View {
        ZStack {
            // Rich gradient background
            LinearGradient(
                colors: [Color(hex: "0A0A0F"), Color(hex: "141420"), Color(hex: "0A0A0F")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroSection

                        if isStudentVerified {
                            studentBadge
                        }

                        if storeKit.isLoadingProducts {
                            loadingState
                        } else if storeKit.subscriptionProducts.isEmpty {
                            fallbackPlanCards
                        } else {
                            planCards
                        }

                        perksComparisonSection

                        restoreButton
                        termsText
                    }
                    .padding(.bottom, 130)
                }

                if selectedProduct != nil || selectedFallback != nil {
                    bottomCTA
                }
            }

            if storeKit.purchaseState == .pending {
                pendingOverlay
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateIn = true }
            fetchStudentStatus()
            autoSelectDefault()
        }
        .onChange(of: storeKit.subscriptionProducts) { _, _ in
            autoSelectDefault()
        }
        .onChange(of: storeKit.purchaseState) { _, newState in
            switch newState {
            case .purchased, .restored:
                dismiss()
            case .failed(let message):
                errorMessage = message
                showError = true
            default:
                break
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") { storeKit.purchaseState = .idle }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "D4AF37"))
                Text("NAVA")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(1.5)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            // Animated crown icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "D4AF37").opacity(0.2), .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "F5D76E"), Color(hex: "D4AF37")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(animateIn ? 1 : 0.5)

            Text("Upgrade to Premium")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Get more matches and unlock exclusive features")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8E8E9A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 8)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    // MARK: - Student Badge

    private var studentBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .foregroundColor(Color(hex: "D4AF37"))
            Text("Student verified — special offers available!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "D4AF37"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "D4AF37").opacity(0.12))
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "D4AF37"))
            Text("Loading plans...")
                .font(.subheadline)
                .foregroundColor(Color(hex: "8E8E9A"))
        }
        .padding(.vertical, 40)
    }

    // MARK: - Tier Card Styling

    private func tierGradient(_ tier: PremiumTier, isSelected: Bool) -> LinearGradient {
        switch tier {
        case .gold:
            return LinearGradient(
                colors: isSelected
                    ? [Color(hex: "2A2214"), Color(hex: "1C1708")]
                    : [Color(hex: "1A1810"), Color(hex: "14130D")],
                startPoint: .top, endPoint: .bottom
            )
        case .platinum:
            return LinearGradient(
                colors: isSelected
                    ? [Color(hex: "221A30"), Color(hex: "17112A")]
                    : [Color(hex: "1A1522"), Color(hex: "13101B")],
                startPoint: .top, endPoint: .bottom
            )
        case .ultra:
            return LinearGradient(
                colors: isSelected
                    ? [Color(hex: "142A28"), Color(hex: "0E201E")]
                    : [Color(hex: "111E1D"), Color(hex: "0D1716")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private func tierCardContent(
        icon: String, name: String, price: String, period: String,
        badge: String?, accent: Color, tier: PremiumTier, isSelected: Bool
    ) -> some View {
        let isRecommended = tier == .platinum

        VStack(spacing: 0) {
            // Badge area
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(0.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 24)
            }

            // Icon with colored glow
            ZStack {
                if isSelected {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                }

                Image(systemName: icon)
                    .font(.system(size: isRecommended ? 26 : 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(accent.opacity(isSelected ? 0.2 : 0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(accent.opacity(isSelected ? 0.4 : 0.1), lineWidth: 1)
                    )
            }
            .padding(.bottom, 10)

            // Name
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 6)

            // Divider line in accent color
            RoundedRectangle(cornerRadius: 1)
                .fill(accent.opacity(0.3))
                .frame(width: 30, height: 2)
                .padding(.bottom, 8)

            // Price
            Text(price)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(accent)

            Text(period)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8E8E9A"))
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isRecommended ? 22 : 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(tierGradient(tier, isSelected: isSelected))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isSelected
                        ? LinearGradient(colors: [accent, accent.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .scaleEffect(isSelected ? 1.04 : 1)
        .shadow(color: isSelected ? accent.opacity(0.3) : .clear, radius: 16, y: 6)
    }

    // MARK: - Fallback Plan Cards

    private var fallbackPlanCards: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(FallbackPlan.all) { plan in
                fallbackPlanCard(plan)
            }
        }
        .padding(.horizontal, 20)
    }

    private func fallbackPlanCard(_ plan: FallbackPlan) -> some View {
        let isSelected = selectedFallback?.id == plan.id

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedFallback = plan
            }
        } label: {
            tierCardContent(
                icon: plan.tier.icon,
                name: plan.tier.displayName,
                price: plan.price,
                period: plan.period,
                badge: plan.tier.badge,
                accent: plan.tier.accentColor,
                tier: plan.tier,
                isSelected: isSelected
            )
        }
    }

    // MARK: - Plan Cards (StoreKit)

    private var planCards: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(storeKit.subscriptionProducts, id: \.id) { product in
                planCard(product)
            }
        }
        .padding(.horizontal, 20)
    }

    private func tierFor(_ product: Product) -> PremiumTier? {
        PremiumTier.allCases.first { $0.storeProductID == product.id }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let tier = tierFor(product)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedProduct = product
            }
        } label: {
            tierCardContent(
                icon: tier?.icon ?? "questionmark",
                name: tier?.displayName ?? product.displayName,
                price: product.displayPrice,
                period: tier != nil && product.subscription != nil
                    ? periodLabel(product.subscription!.subscriptionPeriod)
                    : "",
                badge: tier?.badge,
                accent: tier?.accentColor ?? .gray,
                tier: tier ?? .gold,
                isSelected: isSelected
            )
        }
    }

    // MARK: - Perks Comparison

    private var selectedTier: PremiumTier? {
        if let product = selectedProduct, let tier = tierFor(product) {
            return tier
        } else if let fb = selectedFallback {
            return fb.tier
        }
        return nil
    }

    private var perksComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Compare Plans")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            // Column headers
            HStack(spacing: 0) {
                Text("Feature")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "8E8E9A"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(PremiumTier.allCases, id: \.self) { tier in
                    Text(tier.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tier.accentColor)
                        .frame(width: 52)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "12121A"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            // Perk rows
            VStack(spacing: 0) {
                ForEach(Array(perkRows.enumerated()), id: \.element.id) { index, perk in
                    let isHighlighted = highlightForSelectedTier(perk)

                    HStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: perk.icon)
                                .font(.system(size: 13))
                                .foregroundColor(isHighlighted ? .white : Color(hex: "8E8E9A"))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isHighlighted ? (selectedTier?.accentColor ?? .white).opacity(0.15) : Color.white.opacity(0.04))
                                )

                            Text(perk.title)
                                .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
                                .foregroundColor(isHighlighted ? .white : Color(hex: "8E8E9A"))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        perkIndicator(included: perk.gold, tier: .gold)
                            .frame(width: 52)
                        perkIndicator(included: perk.platinum, tier: .platinum)
                            .frame(width: 52)
                        perkIndicator(included: perk.ultra, tier: .ultra)
                            .frame(width: 52)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isHighlighted ? (selectedTier?.accentColor ?? .clear).opacity(0.05) : .clear)

                    if index < perkRows.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.leading, 54)
                    }
                }
            }
            .background(Color(hex: "15151F"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func highlightForSelectedTier(_ perk: PerkRow) -> Bool {
        guard let tier = selectedTier else { return false }
        switch tier {
        case .gold: return perk.gold
        case .platinum: return perk.platinum
        case .ultra: return perk.ultra
        }
    }

    @ViewBuilder
    private func perkIndicator(included: Bool, tier: PremiumTier) -> some View {
        if included {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tier.accentColor)
        } else {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "3A3A44"))
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task { await storeKit.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8E8E9A"))
        }
    }

    // MARK: - Terms

    private var termsText: some View {
        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
            .font(.system(size: 10))
            .foregroundColor(Color(hex: "555555"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        let tierName: String = {
            if let product = selectedProduct, let tier = tierFor(product) {
                return tier.displayName
            } else if let fb = selectedFallback {
                return fb.tier.displayName
            }
            return ""
        }()

        let priceText: String = {
            if let product = selectedProduct {
                return product.displayPrice
            } else if let fb = selectedFallback {
                return fb.price
            }
            return ""
        }()

        let accent: Color = {
            if let product = selectedProduct, let tier = tierFor(product) {
                return tier.accentColor
            } else if let fb = selectedFallback {
                return fb.tier.accentColor
            }
            return AppColors.primary
        }()

        return VStack(spacing: 10) {
            Button {
                if let product = selectedProduct {
                    Task { await storeKit.purchase(product) }
                } else if selectedFallback != nil {
                    Task {
                        // Retry loading products in case StoreKit wasn't ready
                        await storeKit.loadProducts()
                        if let fb = selectedFallback,
                           let product = storeKit.subscriptionProducts.first(where: { $0.id == fb.id }) {
                            selectedProduct = product
                            selectedFallback = nil
                            await storeKit.purchase(product)
                        } else {
                            errorMessage = "Could not load App Store products. Please ensure you have an internet connection and try again later."
                            showError = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if storeKit.purchaseState == .purchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(storeKit.purchaseState == .purchasing
                         ? "Processing..."
                         : "Get \(tierName) — \(priceText)")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(storeKit.purchaseState == .purchasing)

            Button { dismiss() } label: {
                Text("Maybe later")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "666666"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color(hex: "0A0A0F").opacity(0), Color(hex: "0A0A0F")],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    // MARK: - Pending Overlay

    private var pendingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color(hex: "D4AF37"))
                Text("Purchase Pending")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Your purchase requires approval. You'll get access once it's approved.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Button("OK") {
                    storeKit.purchaseState = .idle
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(Color(hex: "D4AF37"))
                .padding(.top, 8)
            }
            .padding(32)
        }
    }

    // MARK: - Helpers

    private func autoSelectDefault() {
        if !storeKit.subscriptionProducts.isEmpty {
            if selectedProduct == nil {
                let idx = storeKit.subscriptionProducts.count / 2
                selectedProduct = storeKit.subscriptionProducts[idx]
            }
            selectedFallback = nil
        } else if selectedFallback == nil {
            selectedFallback = FallbackPlan.all[1]
        }
    }

    private func fetchStudentStatus() {
        Task {
            struct StudentStatus: Codable { let is_verified: Bool? }
            if let result: StudentStatus = try? await APIService.shared.get(path: "/student/status") {
                isStudentVerified = result.is_verified ?? false
            }
        }
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "/day" : "/\(period.value)d"
        case .week:
            return period.value == 1 ? "/wk" : "/\(period.value)wk"
        case .month:
            return period.value == 1 ? "/mo" : "/\(period.value)mo"
        case .year:
            return period.value == 1 ? "/yr" : "/\(period.value)yr"
        @unknown default:
            return ""
        }
    }
}

#Preview {
    PremiumView()
        .environmentObject(StoreKitManager())
}
