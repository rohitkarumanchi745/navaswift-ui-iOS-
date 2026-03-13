import SwiftUI
import NavCore
import NavNetworking
import NavServices
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
#endif

struct InviteView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var referralCode: String = ""
    @State private var inviteUrl: String = ""
    @State private var shareText: String = ""
    @State private var uses: Int = 0
    @State private var rewardDays: Int = 7
    @State private var isLoading = true
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                headerSection

                // QR Code
                qrCodeSection

                // Referral Code
                referralCodeSection

                // Share Buttons
                shareSection

                // Stats
                if uses > 0 {
                    statsSection
                }

                // How it works
                howItWorksSection
            }
            .padding(24)
        }
        .background(AppColors.darkBg)
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(AppColors.purpleAccent)
            }
        }
        .task { await loadReferralCode() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "6C5CE7"), Color(hex: "C9A0DC")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Invite Friends to Nava")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("Share your code — you and your friend both get \(rewardDays) days of premium free.")
                .font(.subheadline)
                .foregroundColor(AppColors.darkTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - QR Code

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.darkCard)
                    .frame(width: 220, height: 220)
                    .overlay(ProgressView().tint(.white))
            } else if let qrImage = generateQRCode(from: inviteUrl) {
                #if canImport(UIKit)
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "6C5CE7").opacity(0.5), Color(hex: "C9A0DC").opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color(hex: "6C5CE7").opacity(0.3), radius: 12, y: 4)
                #endif
            }

            Text("Scan to join Nava")
                .font(.caption)
                .foregroundColor(AppColors.darkTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Referral Code

    private var referralCodeSection: some View {
        VStack(spacing: 12) {
            Text("YOUR INVITE CODE")
                .font(.caption.bold())
                .foregroundColor(AppColors.darkTextMuted)
                .tracking(1.5)

            HStack(spacing: 12) {
                Text(isLoading ? "------" : referralCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = referralCode
                    #endif
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.title3)
                        .foregroundColor(copied ? Color(hex: "7ED4A6") : AppColors.purpleAccent)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if copied {
                Text("Code copied!")
                    .font(.caption)
                    .foregroundColor(Color(hex: "7ED4A6"))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Share

    private var shareSection: some View {
        VStack(spacing: 12) {
            ShareLink(item: shareText) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Share Invite Link")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading)

            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = inviteUrl
                #endif
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                    Text("Copy Link")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(AppColors.purpleAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            statBadge(count: uses, label: "Friends Joined", icon: "person.fill.checkmark")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statBadge(count: Int, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "7ED4A6"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "7ED4A6").opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.darkTextMuted)
            }

            Spacer()
        }
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HOW IT WORKS")
                .font(.caption.bold())
                .foregroundColor(AppColors.darkTextMuted)
                .tracking(1.5)

            VStack(spacing: 14) {
                stepRow(number: 1, text: "Share your code or QR with friends")
                stepRow(number: 2, text: "They sign up using your invite link")
                stepRow(number: 3, text: "Both of you get \(rewardDays) days of premium free")
            }
            .padding(16)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6C5CE7"), Color(hex: "845EC2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.darkTextSecondary)

            Spacer()
        }
    }

    // MARK: - QR Code Generation

    #if canImport(UIKit)
    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up — raw output is tiny
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif

    // MARK: - API

    private func loadReferralCode() async {
        isLoading = true
        defer { isLoading = false }

        struct ReferralResponse: Codable {
            let code: String?
            let inviteUrl: String?
            let uses: Int?
            let rewardDays: Int?
            let shareText: String?

            enum CodingKeys: String, CodingKey {
                case code
                case inviteUrl = "invite_url"
                case uses
                case rewardDays = "reward_days"
                case shareText = "share_text"
            }
        }

        do {
            let response: ReferralResponse = try await APIService.shared.get(path: "/api/referral/my-code")
            referralCode = response.code ?? generateLocalCode()
            inviteUrl = response.inviteUrl ?? "https://nava.app/invite/\(referralCode)"
            uses = response.uses ?? 0
            rewardDays = response.rewardDays ?? 7
            shareText = response.shareText ?? defaultShareText()
        } catch {
            referralCode = generateLocalCode()
            inviteUrl = "https://nava.app/invite/\(referralCode)"
            uses = 0
            shareText = defaultShareText()
        }
    }

    private func defaultShareText() -> String {
        "Join me on Nava! Use my invite code \(referralCode) and get \(rewardDays) days of premium free. \(inviteUrl)"
    }

    private func generateLocalCode() -> String {
        let userId = auth.user?.id ?? "000"
        let suffix = String(userId.prefix(4)).uppercased()
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let random = String((0..<2).map { _ in chars.randomElement()! })
        return "NAVA\(suffix)\(random)"
    }
}

#Preview {
    NavigationStack {
        InviteView()
            .environmentObject(AuthManager())
    }
}
