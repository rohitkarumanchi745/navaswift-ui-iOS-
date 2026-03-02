import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1F1F1F"))
                
                policyCard {
                    Text("Your privacy is important to us. This Privacy Policy explains how NAVA collects, uses, discloses, and safeguards your information when you use our mobile dating application.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "333333"))
                        .lineSpacing(6)
                }
                
                policyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Information We Collect")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        bulletPoint("Personal information (name, email, phone number)")
                        bulletPoint("Profile information (photos, bio, interests)")
                        bulletPoint("Location data (with your permission)")
                        bulletPoint("Usage data and analytics")
                        bulletPoint("Device information")
                    }
                }
                
                policyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How We Use Your Data")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        bulletPoint("To provide and maintain our service")
                        bulletPoint("To match you with compatible users")
                        bulletPoint("To communicate with you")
                        bulletPoint("To improve our application")
                        bulletPoint("To ensure safety and prevent fraud")
                    }
                }
                
                policyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Rights")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        bulletPoint("Access your personal data")
                        bulletPoint("Request data deletion")
                        bulletPoint("Opt out of marketing communications")
                        bulletPoint("Update or correct your information")
                        bulletPoint("Data portability")
                    }
                }
                
                policyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Us")
                            .font(.headline)
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("If you have questions about this Privacy Policy, please contact us at privacy@nava.app")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "333333"))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func policyCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 4)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(hex: "5F7A66"))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color(hex: "333333"))
                .lineSpacing(4)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
