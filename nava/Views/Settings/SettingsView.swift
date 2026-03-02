import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var notificationsEnabled = true
    @State private var showOnlineStatus = true
    @State private var showDistance = true
    @State private var readReceipts = true
    @State private var showDeleteAlert = false
    @State private var showPauseAlert = false
    @State private var showEditProfile = false
    @State private var showPreferences = false
    @State private var showPremium = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Notifications Section
                settingsSection(title: "Notifications") {
                    toggleRow(icon: "bell.fill", iconColor: AppColors.primary, title: "Push Notifications", isOn: $notificationsEnabled)
                    Divider().padding(.leading, 52)
                    toggleRow(icon: "message.fill", iconColor: AppColors.secondary, title: "Message Notifications", isOn: .constant(true))
                    Divider().padding(.leading, 52)
                    toggleRow(icon: "heart.fill", iconColor: .red, title: "Match Notifications", isOn: .constant(true))
                }
                
                // Privacy Section
                settingsSection(title: "Privacy") {
                    toggleRow(icon: "eye.fill", iconColor: .blue, title: "Show Online Status", isOn: $showOnlineStatus)
                    Divider().padding(.leading, 52)
                    toggleRow(icon: "location.fill", iconColor: .orange, title: "Show Distance", isOn: $showDistance)
                    Divider().padding(.leading, 52)
                    toggleRow(icon: "checkmark.message.fill", iconColor: .green, title: "Read Receipts", isOn: $readReceipts)
                }
                
                // Account Section
                settingsSection(title: "Account") {
                    navigationRow(icon: "person.fill", iconColor: AppColors.accent, title: "Edit Profile") {
                        showEditProfile = true
                    }
                    Divider().padding(.leading, 52)
                    navigationRow(icon: "slider.horizontal.3", iconColor: AppColors.secondary, title: "Dating Preferences") {
                        showPreferences = true
                    }
                    Divider().padding(.leading, 52)
                    navigationRow(icon: "crown.fill", iconColor: Color(hex: "D4AF37"), title: "Premium") {
                        showPremium = true
                    }
                }
                
                // Support Section
                settingsSection(title: "Support") {
                    navigationRow(icon: "questionmark.circle.fill", iconColor: .blue, title: "Help Center") {}
                    Divider().padding(.leading, 52)
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 32)
                            Text("Privacy Policy")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                                .frame(width: 32)
                            Text("Terms of Service")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding(.vertical, 4)
                    }
                    Divider().padding(.leading, 52)
                    navigationRow(icon: "envelope.fill", iconColor: AppColors.primary, title: "Contact Us") {}
                }
                
                // Danger Zone
                settingsSection(title: "Danger Zone") {
                    Button {
                        showPauseAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "pause.circle.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                                .frame(width: 32)
                            
                            Text("Pause Account")
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider().padding(.leading, 52)
                    
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.error)
                                .frame(width: 32)
                            
                            Text("Delete Account")
                                .foregroundColor(AppColors.error)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // App info
                VStack(spacing: 4) {
                    Text("NAVA v1.0.0")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                    Text("Made with ❤️ in India")
                        .font(.caption2)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .padding(16)
        }
        .background(Color(hex: "F8F9FA"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Pause Account", isPresented: $showPauseAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Pause", role: .destructive) {}
        } message: {
            Text("Your profile will be hidden from discovery. You can resume anytime.")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {}
        } message: {
            Text("This action is permanent. All your data, matches, and messages will be deleted.")
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
    }
    
    // MARK: - Helpers
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(AppColors.textMuted)
                .padding(.bottom, 8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func toggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.primary)
        }
        .padding(.vertical, 4)
    }
    
    private func navigationRow(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager())
    }
}
