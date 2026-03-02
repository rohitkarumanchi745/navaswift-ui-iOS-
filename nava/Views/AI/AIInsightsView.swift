import SwiftUI

struct AIInsightsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AI Insights")
                    .font(AppTypography.h2)
                    .foregroundColor(AppColors.textPrimary)
                
                infoCard(icon: "brain.head.profile", title: "Compatibility Scores", color: AppColors.accent) {
                    Text("Our AI analyzes shared interests, communication patterns, and behavioral signals to generate compatibility scores for each potential match.")
                }
                
                infoCard(icon: "chart.line.uptrend.xyaxis", title: "Profile Insights", color: AppColors.secondary) {
                    Text("Track how your profile performs — views, likes received, and engagement trends over time.")
                }
                
                infoCard(icon: "lightbulb.fill", title: "Smart Suggestions", color: .orange) {
                    Text("Get personalized tips to improve your profile, optimize your bio, and increase your match rate.")
                }
                
                infoCard(icon: "shield.checkered", title: "Safety Scoring", color: .green) {
                    Text("AI-powered verification helps identify authentic profiles and flag suspicious activity to keep you safe.")
                }
                
                NavigationLink(destination: AIExplanationView()) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(AppColors.accent)
                        Text("How does the AI work?")
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
                }
            }
            .padding(24)
        }
        .background(AppColors.peachBackground)
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoCard(icon: String, title: String, color: Color, @ViewBuilder description: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            description()
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
}

struct AIExplanationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How the AI Works")
                    .font(AppTypography.h2)
                    .foregroundColor(AppColors.textPrimary)
                
                explanationCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transparency First")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("At NAVA, we believe in transparent AI. Our matching algorithms consider multiple factors to suggest compatible matches while respecting your preferences and privacy.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                }
                
                explanationCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What We Analyze")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        factorRow("Shared interests and hobbies")
                        factorRow("Communication style compatibility")
                        factorRow("Location proximity")
                        factorRow("Response patterns and engagement")
                        factorRow("Preference alignment")
                    }
                }
                
                explanationCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What We Don't Do")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        factorRow("We never sell your personal data")
                        factorRow("We don't discriminate based on race or ethnicity")
                        factorRow("We don't read your private messages")
                        factorRow("We don't share your swipe history")
                    }
                }
            }
            .padding(24)
        }
        .background(AppColors.peachBackground)
        .navigationTitle("How AI Works")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func explanationCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
    
    private func factorRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.verifyGreen)
                .font(.subheadline)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
    }
}
