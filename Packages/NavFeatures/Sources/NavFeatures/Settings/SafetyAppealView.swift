import SwiftUI
import NavCore
import NavNetworking
import NavServices

/// Allows users to appeal a moderation decision on their content.
/// Shows the moderation reason, lets the user add context, and submits an appeal
/// with automatic retry on failure.
struct SafetyAppealView: View {
    @Environment(\.dismiss) var dismiss

    let photoId: String
    let moderationStatus: ModerationStatus

    @State private var appealText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var didSucceed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                reasonSection
                appealFormSection

                if let error = submitError {
                    ErrorBanner(style: .error(error)) {
                        submitAppeal()
                    }
                    .accessibilityIdentifier("appealErrorBanner")
                }

                if didSucceed {
                    successBanner
                        .accessibilityIdentifier("appealSuccessBanner")
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background)
        .navigationTitle("Appeal Decision")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Submit") {
                    submitAppeal()
                }
                .disabled(appealText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || didSucceed)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.primary)

            Text("Content Review Appeal")
                .font(.title3.bold())
                .foregroundColor(AppColors.textPrimary)

            Text("If you believe your content was incorrectly flagged, you can request a manual review.")
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODERATION REASON")
                .font(.caption.bold())
                .foregroundColor(AppColors.textMuted)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                Image(systemName: moderationStatus == .rejected ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(moderationStatus == .rejected ? AppColors.error : .orange)
                    .frame(width: 32)

                Text(moderationStatus.reason)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var appealFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR EXPLANATION")
                .font(.caption.bold())
                .foregroundColor(AppColors.textMuted)
                .padding(.leading, 4)

            TextEditor(text: $appealText)
                .frame(minHeight: 120)
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    Group {
                        if appealText.isEmpty {
                            Text("Explain why you think this decision should be reconsidered...")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textMuted)
                                .padding(.leading, 16)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .disabled(isSubmitting || didSucceed)
        }
    }

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            Text("Appeal submitted. We'll review it and notify you.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "203A20"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    private func submitAppeal() {
        let trimmed = appealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            isSubmitting = true
            submitError = nil

            struct AppealResponse: Decodable {
                let success: Bool?
                let appealId: String?
            }

            let body: [String: Any] = [
                "photo_id": photoId,
                "reason": trimmed,
            ]

            let start = CFAbsoluteTimeGetCurrent()

            do {
                let _: AppealResponse = try await APIService.shared.post(
                    path: "/api/safety/appeal",
                    body: body
                )
                let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
                NetworkMetrics.shared.recordSuccess(
                    endpoint: "safety/appeal",
                    method: "POST",
                    statusCode: 200,
                    latencyMs: latencyMs
                )
                didSucceed = true
                NavLog.info("Safety appeal submitted for photo \(photoId) in \(Int(latencyMs))ms", category: .general)
            } catch {
                let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
                NetworkMetrics.shared.recordError(
                    endpoint: "safety/appeal",
                    method: "POST",
                    statusCode: nil,
                    latencyMs: latencyMs,
                    error: error.localizedDescription
                )
                submitError = "Failed to submit appeal. Tap retry."
                NavLog.warning("Safety appeal failed for photo \(photoId) in \(Int(latencyMs))ms: \(error.localizedDescription)", category: .network)
            }
            isSubmitting = false
        }
    }
}
