import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct AIInsightsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var insights: AIInsightsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var animateOrbs = false
    @State private var animateScore = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1A1B2E"), Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs
            Circle()
                .fill(Color(hex: "9B7FCA").opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: animateOrbs ? -250 : -210)

            Circle()
                .fill(Color(hex: "A8D8EA").opacity(0.06))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .offset(x: 100, y: animateOrbs ? 280 : 240)

            if isLoading {
                loadingView
            } else if let error = errorMessage, insights == nil {
                errorView(error)
            } else if let data = insights {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Overall score ring
                        overallScoreCard(data)

                        // Highlights
                        if let h = highlightItems(data.highlights), !h.isEmpty {
                            highlightsCard(h)
                        }

                        // Breakdown scores
                        breakdownSection(data.breakdown)

                        // How it works link
                        howItWorksCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadInsights() }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
    }

    // MARK: - Overall Score

    private func overallScoreCard(_ data: AIInsightsResponse) -> some View {
        VStack(spacing: 16) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: animateScore ? CGFloat(data.compatibilityScore) / 100.0 : 0)
                    .stroke(
                        scoreGradient(data.compatibilityScore),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(data.compatibilityScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ 100")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animateScore = true
                }
            }

            Text(data.compatibilityLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(scoreColor(data.compatibilityScore))

            Text("Based on personality, interests, and preferences")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(AppColors.darkCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Highlights

    private func highlightItems(_ h: AIHighlights) -> [(icon: String, text: String, color: Color)]? {
        var items: [(icon: String, text: String, color: Color)] = []
        if h.sameUniversity == true, let uni = h.university {
            items.append(("graduationcap.fill", "Same university: \(uni)", AppColors.purpleAccent))
        }
        if h.cfSignal == true, let label = h.cfLabel {
            items.append(("person.2.fill", label, AppColors.superLike))
        }
        return items.isEmpty ? nil : items
    }

    private func highlightsCard(_ items: [(icon: String, text: String, color: Color)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.gold)
                Text("Highlights")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(item.color)
                        .frame(width: 28)
                    Text(item.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Breakdown

    private func breakdownSection(_ b: AIBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.purpleAccent)
                Text("Breakdown")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            scoreRow(icon: "brain.head.profile", label: "Personality", score: b.personalityMatch.score, subtitle: b.personalityMatch.label, weight: b.personalityMatch.weightPct)

            scoreRow(icon: "heart.fill", label: "Interests", score: b.sharedInterests.score, subtitle: sharedTagLine(b.sharedInterests.shared, fallback: b.sharedInterests.label), weight: b.sharedInterests.weightPct)

            scoreRow(icon: "globe", label: "Languages", score: b.sharedLanguages.score, subtitle: sharedTagLine(b.sharedLanguages.shared, fallback: b.sharedLanguages.label), weight: b.sharedLanguages.weightPct)

            scoreRow(icon: "arrow.triangle.merge", label: "Goals", score: b.relationshipGoals.score, subtitle: b.relationshipGoals.label, weight: b.relationshipGoals.weightPct)

            scoreRow(icon: "location.fill", label: "Proximity", score: b.proximity.score, subtitle: b.proximity.label, weight: b.proximity.weightPct)

            // Super like boost
            if b.superLikeBoost.active {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.superLike)
                        .frame(width: 28)
                    Text("Super Like Boost Active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.superLike)
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.superLike)
                }
                .padding(12)
                .background(AppColors.superLike.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func scoreRow(icon: String, label: String, score: Int, subtitle: String, weight: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(scoreColor(score))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))
                Text("(\(weight)%)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * CGFloat(score) / 100.0, height: 6)
                }
            }
            .frame(height: 6)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.vertical, 4)
    }

    private func sharedTagLine(_ items: [String]?, fallback: String) -> String {
        guard let items, !items.isEmpty else { return fallback }
        return items.joined(separator: ", ")
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        NavigationLink(destination: AIExplanationView()) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.purpleAccent)
                Text("How does the AI work?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(AppColors.darkCard.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(AppColors.purpleAccent)
                .scaleEffect(1.2)
            Text("Analyzing your profile...")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadInsights() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColors.purpleAccent)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Score Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return AppColors.like
        case 60..<80: return AppColors.superLike
        case 40..<60: return AppColors.warning
        default: return AppColors.error
        }
    }

    private func scoreGradient(_ score: Int) -> LinearGradient {
        let color = scoreColor(score)
        return LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - API

    private func loadInsights() async {
        guard let userId = auth.user?.id else {
            errorMessage = "Please log in to see insights"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result: AIInsightsResponse = try await APIService.shared.get(
                path: "/ai/insights/\(userId)"
            )
            insights = result
        } catch {
            insights = nil
        }
        isLoading = false
    }
}

// MARK: - How AI Works (dark theme)

struct AIExplanationView: View {
    @State private var animateOrbs = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1B2E"), Color(hex: "2D1B4E"), Color(hex: "1A1B2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "9B7FCA").opacity(0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 80, y: animateOrbs ? -200 : -170)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    explanationCard(title: "Transparency First", text: "Our matching algorithms consider multiple factors to suggest compatible matches while respecting your preferences and privacy.")

                    explanationCard(title: "What We Analyze") {
                        VStack(alignment: .leading, spacing: 10) {
                            factorRow("Shared interests and hobbies")
                            factorRow("Communication style compatibility")
                            factorRow("Location proximity")
                            factorRow("Response patterns and engagement")
                            factorRow("Preference alignment")
                        }
                    }

                    explanationCard(title: "What We Don't Do") {
                        VStack(alignment: .leading, spacing: 10) {
                            factorRow("We never sell your personal data")
                            factorRow("We don't discriminate based on race or ethnicity")
                            factorRow("We don't read your private messages")
                            factorRow("We don't share your swipe history")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("How AI Works")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
    }

    private func explanationCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func explanationCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.darkCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func factorRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.like)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .environmentObject(AuthManager())
    }
}
