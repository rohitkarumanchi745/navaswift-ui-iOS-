import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1F1F1F"))
                
                termsCard {
                    Text("By using NAVA, you agree to be bound by these Terms of Service. Please read them carefully before using our application.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "333333"))
                        .lineSpacing(6)
                }
                
                termsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Eligibility")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("You must be at least 18 years old to use NAVA. By creating an account, you confirm that you meet this requirement and that the information you provide is accurate.")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "333333"))
                            .lineSpacing(4)
                    }
                }
                
                termsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("User Conduct")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("You agree to use NAVA respectfully and responsibly. Harassment, spam, impersonation, and sharing inappropriate content are strictly prohibited and may result in account termination.")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "333333"))
                            .lineSpacing(4)
                    }
                }
                
                termsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subscriptions")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("Premium subscriptions are billed through the App Store. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Refunds are handled according to Apple's refund policies.")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "333333"))
                            .lineSpacing(4)
                    }
                }
                
                termsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Limitation of Liability")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("NAVA is not responsible for the behavior of its users. We encourage you to exercise caution and meet in public places. Report any suspicious activity through the app.")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "333333"))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func termsCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
