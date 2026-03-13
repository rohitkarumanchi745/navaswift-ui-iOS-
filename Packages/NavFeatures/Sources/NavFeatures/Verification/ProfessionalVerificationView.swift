import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct ProfessionalVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case info, code, verified }

    @State private var step: Step = .info
    @State private var orgName = ""
    @State private var membershipId = ""
    @State private var eventCode = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let benefits = [
        ("briefcase.fill", "Verified professional badge"),
        ("message.fill", "Limited direct-message pass"),
        ("person.3.fill", "Access to niche meetups"),
        ("star.fill", "Priority in professional filters"),
    ]

    private let popularOrgs = [
        "Product Management Club",
        "Designers Guild",
        "Medical Association",
        "Law Society",
        "Tech Founders Network",
        "Finance Professionals",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                VStack(spacing: 24) {
                    if step == .verified { verifiedContent }
                    else if step == .info { infoContent }
                    else { codeContent }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F7E8D1"))
        .navigationTitle("Professional Verification").navigationBarTitleDisplayMode(.inline)
        .alert("Professional Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
        .task { await loadProfessionalStatus() }
    }

    // MARK: - Verified
    private var verifiedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "D4872C"))
            Text("Professional Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            if !orgName.isEmpty {
                Text(orgName).font(.subheadline.bold()).foregroundColor(Color(hex: "B8742A"))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(hex: "B8742A").opacity(0.1)).clipShape(Capsule())
            }

            Text("You now have access to professional networking features and a limited direct-message pass.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            Button { dismiss() } label: {
                Text("Continue").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "B8742A"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Info Step
    private var infoContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "briefcase.fill").font(.system(size: 48)).foregroundColor(Color(hex: "B8742A"))
            Text("Professional Club").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Verify your membership in a professional club or meetup group to unlock networking features.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Organization / Club").font(.caption.bold()).foregroundColor(Color(hex: "B8742A"))
                TextField("Organization name", text: $orgName)
                    .padding(14).background(Color(hex: "F4EBE0"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Popular clubs").font(.caption).foregroundColor(Color(hex: "999999"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularOrgs, id: \.self) { org in
                            Button {
                                orgName = org
                            } label: {
                                Text(org).font(.system(size: 12, weight: .medium))
                                    .foregroundColor(orgName == org ? .white : Color(hex: "B8742A"))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(orgName == org ? Color(hex: "B8742A") : Color(hex: "F4EBE0"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Text("Membership ID (optional)").font(.caption.bold()).foregroundColor(Color(hex: "B8742A"))
                TextField("Your membership or member ID", text: $membershipId)
                    .padding(14).background(Color(hex: "F4EBE0"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 12) {
                Button {
                    withAnimation { step = .code }
                } label: {
                    Text("I have an event code").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "B8742A"))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(orgName.isEmpty)
                .opacity(orgName.isEmpty ? 0.6 : 1)

                Button { submitWithoutCode() } label: {
                    Text("Submit for manual review").font(.subheadline).foregroundColor(Color(hex: "B8742A"))
                }
                .disabled(orgName.isEmpty)
            }

            Divider().padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(benefits, id: \.1) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: benefit.0).foregroundColor(Color(hex: "B8742A")).frame(width: 24)
                        Text(benefit.1).font(.subheadline).foregroundColor(Color(hex: "333333"))
                    }
                }
            }
        }
    }

    // MARK: - Event Code Step
    private var codeContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .info } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "B8742A"))
                }
                Spacer()
            }

            Image(systemName: "qrcode.viewfinder").font(.system(size: 48)).foregroundColor(Color(hex: "B8742A"))
            Text("Event Code").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Enter the event code provided at the meetup or scan the QR code at the venue.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            if !orgName.isEmpty {
                Text(orgName).font(.caption.bold()).foregroundColor(Color(hex: "B8742A"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "B8742A").opacity(0.1)).clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Image(systemName: "ticket.fill").foregroundColor(Color(hex: "C99A5C"))
                TextField("Enter event code", text: $eventCode)
                    .autocapitalization(.allCharacters)
            }
            .padding(16).background(Color(hex: "F4EBE0"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button { verifyEventCode() } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Verifying..." : "Verify Code").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "B8742A"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(eventCode.isEmpty || isSubmitting)
            .opacity(eventCode.isEmpty ? 0.6 : 1)
        }
    }

    // MARK: - API

    private func loadProfessionalStatus() async {
        if auth.user?.isProfessionalVerified == true { step = .verified; return }
        do {
            struct StatusResponse: Codable { let is_verified: Bool?; let org_name: String? }
            let result: StatusResponse = try await APIService.shared.get(path: "/professional/status")
            if result.is_verified == true {
                orgName = result.org_name ?? ""
                step = .verified
            }
        } catch {}
    }

    private func verifyEventCode() {
        isSubmitting = true
        Task {
            do {
                struct VerifyResponse: Codable { let verified: Bool?; let org_name: String? }
                let body: [String: Any] = [
                    "org_name": orgName,
                    "event_code": eventCode,
                    "membership_id": membershipId
                ]
                let result: VerifyResponse = try await APIService.shared.post(path: "/professional/verify", body: body)
                if result.verified == true {
                    await auth.refreshProfile()
                    withAnimation { step = .verified }
                } else {
                    alertMessage = "Invalid event code. Please check and try again."
                    showAlert = true
                }
            } catch {
                alertMessage = "Verification failed. Please try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func submitWithoutCode() {
        isSubmitting = true
        Task {
            do {
                struct ReviewResponse: Codable { let submitted: Bool?; let message: String? }
                let body: [String: Any] = [
                    "org_name": orgName,
                    "membership_id": membershipId
                ]
                let result: ReviewResponse = try await APIService.shared.post(path: "/professional/review-request", body: body)
                alertMessage = result.message ?? "Your request has been submitted for manual review. You'll be notified once verified."
                showAlert = true
            } catch {
                alertMessage = "Failed to submit. Please try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        ProfessionalVerificationView()
            .environmentObject(AuthManager())
    }
}
