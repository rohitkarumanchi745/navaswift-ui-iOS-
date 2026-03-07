import SwiftUI
import StoreKit
import NavCore
import NavNetworking
import NavServices

struct PremiumView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var selectedProduct: Product?
    @State private var isStudentVerified = false
    @State private var animateIn = false
    @State private var showError = false
    @State private var errorMessage = ""

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
            Color(hex: "0F0F0F")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroSection

                        if isStudentVerified {
                            studentBadge
                        }

                        if storeKit.isLoadingProducts {
                            loadingState
                        } else if storeKit.subscriptionProducts.isEmpty {
                            errorState
                        } else {
                            planCards
                            perksGrid
                            if selectedProduct != nil {
                                selectedPlanFeatures
                            }
                        }

                        restoreButton
                        termsText
                    }
                    .padding(.bottom, 120)
                }

                if selectedProduct != nil {
                    bottomCTA
                }
            }

            if storeKit.purchaseState == .pending {
                pendingOverlay
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animateIn = true }
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
            Text("Student verified — you may qualify for special offers!")
                .font(.subheadline.bold())
                .foregroundColor(Color(hex: "D4AF37"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "D4AF37").opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "D4AF37"))
            Text("Loading plans...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.title)
                .foregroundColor(.gray)
            Text("Could not load plans")
                .font(.subheadline)
                .foregroundColor(.gray)
            Button("Retry") {
                Task { await storeKit.loadProducts() }
            }
            .font(.subheadline.bold())
            .foregroundColor(Color(hex: "D4AF37"))
        }
        .padding(.vertical, 40)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(storeKit.subscriptionProducts, id: \.id) { product in
                    planCard(product)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func tierFor(_ product: Product) -> PremiumTier? {
        PremiumTier.allCases.first { $0.storeProductID == product.id }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let tier = tierFor(product)
        let accent = tier?.accentColor ?? .gray

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedProduct = product
            }
        } label: {
            VStack(spacing: 10) {
                if let badge = tier?.badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 18)
                }

                Image(systemName: tier?.icon ?? "questionmark")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : accent)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected ?
                        AnyShapeStyle(accent) :
                        AnyShapeStyle(accent.opacity(0.15))
                    )
                    .clipShape(Circle())

                Text(tier?.displayName ?? product.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text(product.displayPrice)
                    .font(.headline.bold())
                    .foregroundColor(accent)

                if let sub = product.subscription {
                    Text(periodLabel(sub.subscriptionPeriod))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 110)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "252525") : Color(hex: "1A1A1A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? accent : Color(hex: "333333"),
                                    lineWidth: isSelected ? 2 : 1)
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
        Group {
            if let product = selectedProduct, let tier = tierFor(product) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(tier.displayName) includes:")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(tier.features, id: \.self) { feature in
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
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task { await storeKit.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Terms

    private var termsText: some View {
        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
            .font(.caption2)
            .foregroundColor(Color(hex: "666666"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 12) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await storeKit.purchase(product) }
            } label: {
                HStack {
                    if storeKit.purchaseState == .purchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    let tier = selectedProduct.flatMap { tierFor($0) }
                    Text(storeKit.purchaseState == .purchasing
                         ? "Processing..."
                         : "Get \(tier?.displayName ?? "") — \(selectedProduct?.displayPrice ?? "")")
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
            .disabled(storeKit.purchaseState == .purchasing)

            Button { dismiss() } label: {
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
        guard selectedProduct == nil, !storeKit.subscriptionProducts.isEmpty else { return }
        let idx = storeKit.subscriptionProducts.count / 2
        selectedProduct = storeKit.subscriptionProducts[idx]
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
            return period.value == 1 ? "per day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "per week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "per month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "per year" : "\(period.value) years"
        @unknown default:
            return ""
        }
    }
}

#Preview {
    PremiumView()
        .environmentObject(StoreKitManager())
}
