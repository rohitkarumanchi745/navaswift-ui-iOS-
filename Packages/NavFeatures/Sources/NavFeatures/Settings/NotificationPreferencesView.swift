import SwiftUI
import NavCore
import NavNetworking

/// Notification preferences with quiet hours, per-type toggles, and system settings link.
struct NotificationPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("settings_notifications") private var pushEnabled = true
    @AppStorage("notif_messages") private var messagesEnabled = true
    @AppStorage("notif_matches") private var matchesEnabled = true
    @AppStorage("notif_likes") private var likesEnabled = true
    @AppStorage("notif_reels") private var reelsEnabled = true
    @AppStorage("notif_quiet_hours") private var quietHoursEnabled = false
    @AppStorage("notif_quiet_start_hour") private var quietStartHour = 22
    @AppStorage("notif_quiet_start_minute") private var quietStartMinute = 0
    @AppStorage("notif_quiet_end_hour") private var quietEndHour = 8
    @AppStorage("notif_quiet_end_minute") private var quietEndMinute = 0

    @State private var quietStart = Date()
    @State private var quietEnd = Date()
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                masterToggleSection
                categorySection
                quietHoursSection
                systemSettingsSection
            }
            .padding(16)
        }
        .background(AppColors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    savePreferences()
                    dismiss()
                }
            }
        }
        .onAppear { loadTimePickers() }
    }

    // MARK: - Sections

    private var masterToggleSection: some View {
        settingsCard {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(pushEnabled ? "Enabled" : "All notifications paused")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
                Spacer()
                Toggle("", isOn: $pushEnabled)
                    .labelsHidden()
                    .tint(AppColors.primary)
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NOTIFICATION TYPES")
                .font(.caption.bold())
                .foregroundColor(AppColors.textMuted)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            settingsCard {
                categoryToggle(icon: "message.fill", color: .blue, title: "Messages", subtitle: "New chat messages", isOn: $messagesEnabled)
                Divider().padding(.leading, 52)
                categoryToggle(icon: "heart.fill", color: .red, title: "Matches", subtitle: "Mutual match alerts", isOn: $matchesEnabled)
                Divider().padding(.leading, 52)
                categoryToggle(icon: "star.fill", color: .orange, title: "Likes", subtitle: "Someone liked your profile", isOn: $likesEnabled)
                Divider().padding(.leading, 52)
                categoryToggle(icon: "play.rectangle.fill", color: .purple, title: "Reels", subtitle: "New reels from matches", isOn: $reelsEnabled)
            }
        }
        .opacity(pushEnabled ? 1 : 0.5)
        .disabled(!pushEnabled)
    }

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUIET HOURS")
                .font(.caption.bold())
                .foregroundColor(AppColors.textMuted)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            settingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "moon.fill")
                        .font(.title3)
                        .foregroundColor(.indigo)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet Hours")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Silence notifications during set hours")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    Spacer()
                    Toggle("", isOn: $quietHoursEnabled)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }

                if quietHoursEnabled {
                    Divider().padding(.leading, 52)

                    VStack(spacing: 12) {
                        HStack {
                            Text("From")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            DatePicker("", selection: $quietStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: quietStart) { _, newVal in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newVal)
                                    quietStartHour = comps.hour ?? 22
                                    quietStartMinute = comps.minute ?? 0
                                }
                        }

                        HStack {
                            Text("To")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            DatePicker("", selection: $quietEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: quietEnd) { _, newVal in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newVal)
                                    quietEndHour = comps.hour ?? 8
                                    quietEndMinute = comps.minute ?? 0
                                }
                        }
                    }
                    .padding(.leading, 44)
                    .padding(.vertical, 4)
                }
            }
        }
        .opacity(pushEnabled ? 1 : 0.5)
        .disabled(!pushEnabled)
    }

    private var systemSettingsSection: some View {
        settingsCard {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Settings")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Manage permissions in iOS Settings")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
    }

    // MARK: - Helpers

    private func categoryToggle(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.primary)
        }
        .padding(.vertical, 2)
    }

    private func settingsCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadTimePickers() {
        var startComps = DateComponents()
        startComps.hour = quietStartHour
        startComps.minute = quietStartMinute
        quietStart = Calendar.current.date(from: startComps) ?? Date()

        var endComps = DateComponents()
        endComps.hour = quietEndHour
        endComps.minute = quietEndMinute
        quietEnd = Calendar.current.date(from: endComps) ?? Date()
    }

    private func savePreferences() {
        Task {
            isSaving = true
            struct SaveResponse: Decodable { let success: Bool? }
            let body: [String: Any] = [
                "push_enabled": pushEnabled,
                "messages": messagesEnabled,
                "matches": matchesEnabled,
                "likes": likesEnabled,
                "reels": reelsEnabled,
                "quiet_hours_enabled": quietHoursEnabled,
                "quiet_start": "\(quietStartHour):\(String(format: "%02d", quietStartMinute))",
                "quiet_end": "\(quietEndHour):\(String(format: "%02d", quietEndMinute))",
            ]
            do {
                let _: SaveResponse = try await APIService.shared.post(
                    path: "/api/notifications/preferences",
                    body: body
                )
                NavLog.info("Notification preferences saved", category: .network)
            } catch {
                NavLog.warning("Failed to save notification preferences: \(error.localizedDescription)", category: .network)
            }
            isSaving = false
        }
    }
}
