import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("settings_notifications") private var notificationsEnabled = true
    @AppStorage("settings_online_status") private var showOnlineStatus = true
    @AppStorage("settings_show_distance") private var showDistance = true
    @AppStorage("settings_read_receipts") private var readReceipts = true
    @State private var showDeleteAlert = false
    @State private var showPauseAlert = false
    @State private var isPausing = false
    @State private var isDeleting = false
    @State private var showEditProfile = false
    @State private var showPreferences = false
    @State private var showPremium = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                notificationsSection
                privacySection
                accountSection
                supportSection
                dangerZoneSection
                appInfoFooter
            }
            .padding(16)
        }
        .background(AppColors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Pause Account", isPresented: $showPauseAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Pause", role: .destructive) {
                Task {
                    isPausing = true
                    auth.logout()
                    isPausing = false
                }
            }
        } message: {
            Text("Your profile will be hidden from discovery. You can resume anytime by signing back in.")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
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

    // MARK: - Sections

    private var notificationsSection: some View {
        settingsSection(title: "Notifications") {
            toggleRow(icon: "bell.fill", iconColor: AppColors.primary, title: "Push Notifications", isOn: $notificationsEnabled)
            Divider().padding(.leading, 52)
            toggleRow(icon: "message.fill", iconColor: AppColors.secondary, title: "Message Notifications", isOn: .constant(true))
            Divider().padding(.leading, 52)
            toggleRow(icon: "heart.fill", iconColor: .red, title: "Match Notifications", isOn: .constant(true))
        }
    }

    private var privacySection: some View {
        settingsSection(title: "Privacy") {
            toggleRow(icon: "eye.fill", iconColor: .blue, title: "Show Online Status", isOn: $showOnlineStatus)
            Divider().padding(.leading, 52)
            toggleRow(icon: "location.fill", iconColor: .orange, title: "Show Distance", isOn: $showDistance)
            Divider().padding(.leading, 52)
            toggleRow(icon: "checkmark.message.fill", iconColor: .green, title: "Read Receipts", isOn: $readReceipts)
        }
    }

    private var accountSection: some View {
        settingsSection(title: "Account") {
            navigationRow(icon: "person.fill", iconColor: AppColors.accent, title: "Edit Profile") {
                showEditProfile = true
            }
            Divider().padding(.leading, 52)
            navigationRow(icon: "slider.horizontal.3", iconColor: AppColors.secondary, title: "Dating Preferences") {
                showPreferences = true
            }
            Divider().padding(.leading, 52)
            navigationRow(icon: "crown.fill", iconColor: Color(hex: "D4AF37"), title: storeKit.isPremium ? "Premium (Active)" : "Premium") {
                showPremium = true
            }
        }
    }

    private var supportSection: some View {
        settingsSection(title: "Support") {
            navigationRow(icon: "questionmark.circle.fill", iconColor: .blue, title: "Help Center") {
                if let url = URL(string: "https://nava.app/help") {
                    UIApplication.shared.open(url)
                }
            }
            Divider().padding(.leading, 52)
            NavigationLink(destination: PrivacyPolicyView()) {
                linkRow(icon: "shield.fill", iconColor: .green, title: "Privacy Policy")
            }
            Divider().padding(.leading, 52)
            NavigationLink(destination: TermsOfServiceView()) {
                linkRow(icon: "doc.text.fill", iconColor: .gray, title: "Terms of Service")
            }
            Divider().padding(.leading, 52)
            navigationRow(icon: "envelope.fill", iconColor: AppColors.primary, title: "Contact Us") {
                if let url = URL(string: "mailto:support@nava.app") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var dangerZoneSection: some View {
        settingsSection(title: "Danger Zone") {
            Button {
                showPauseAlert = true
            } label: {
                linkRow(icon: "pause.circle.fill", iconColor: .orange, title: "Pause Account", titleColor: .orange)
            }

            Divider().padding(.leading, 52)

            Button {
                showDeleteAlert = true
            } label: {
                linkRow(icon: "trash.fill", iconColor: AppColors.error, title: "Delete Account", titleColor: AppColors.error)
            }
        }
    }

    private var appInfoFooter: some View {
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

    // MARK: - Actions

    private func deleteAccount() {
        Task {
            isDeleting = true
            struct DeleteResponse: Codable { let success: Bool? }
            let _: DeleteResponse? = try? await APIService.shared.post(
                path: "/account/delete",
                body: ["confirm": true]
            )
            auth.logout()
            isDeleting = false
        }
    }

    // MARK: - Reusable Components

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
                .font(.title3).foregroundColor(iconColor).frame(width: 32)
            Text(title).font(.subheadline).foregroundColor(AppColors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(AppColors.primary)
        }
        .padding(.vertical, 4)
    }

    private func navigationRow(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            linkRow(icon: icon, iconColor: iconColor, title: title)
        }
    }

    private func linkRow(icon: String, iconColor: Color, title: String, titleColor: Color = AppColors.textPrimary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundColor(iconColor).frame(width: 32)
            Text(title).font(.subheadline).foregroundColor(titleColor)
            Spacer()
            if titleColor == AppColors.textPrimary {
                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager())
            .environmentObject(StoreKitManager())
    }
}
