import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct CampusVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case info, enterCode, networkCheck, result }

    @State private var step: Step = .info
    @State private var eventCode = ""
    @State private var isSubmitting = false
    @State private var isCheckingNetwork = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var verifiedUniversity = ""
    @State private var verifiedEventName = ""
    @State private var networkCheckResult: String?  // nil = not checked, "on_campus", "off_campus"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 30)

                VStack(spacing: 24) {
                    switch step {
                    case .info: infoContent
                    case .enterCode: codeContent
                    case .networkCheck: networkContent
                    case .result: resultContent
                    }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F0E8D8"))
        .navigationTitle("Campus Verification").navigationBarTitleDisplayMode(.inline)
        .alert("Campus Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
    }

    // MARK: - Info

    private var infoContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 44)).foregroundColor(Color(hex: "8B6914"))

            VStack(spacing: 8) {
                Text("Campus Verification").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Get verified in person at a campus event booth, or check in from your campus network.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            // Option 1: Event code / QR
            Button {
                withAnimation { step = .enterCode }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "8B6914"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "8B6914").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Event Code / QR Scan").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "1F1F1F"))
                        Text("Enter code from a campus verification booth").font(.system(size: 12)).foregroundColor(Color(hex: "888888"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "CCCCCC"))
                }
                .padding(14)
                .background(Color(hex: "FFF9EE"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "8B6914").opacity(0.15), lineWidth: 1))
            }

            // Option 2: Campus network check
            Button {
                withAnimation { step = .networkCheck }
                checkCampusNetwork()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wifi")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "4A90D9"))
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "4A90D9").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campus Network Check").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "1F1F1F"))
                        Text("Verify from your campus Wi-Fi (secondary signal)").font(.system(size: 12)).foregroundColor(Color(hex: "888888"))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "CCCCCC"))
                }
                .padding(14)
                .background(Color(hex: "EEF4FF"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "4A90D9").opacity(0.15), lineWidth: 1))
            }

            // Info box
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "8B6914"))
                Text("Campus network check is a supplemental signal. For full verification, use an event code or combine with another verification method.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
            }
            .padding(12).background(Color(hex: "FFF9EE")).clipShape(RoundedRectangle(cornerRadius: 10))

            // Benefits
            VStack(alignment: .leading, spacing: 10) {
                Text("In-person verification benefits").font(.caption.bold()).foregroundColor(Color(hex: "8B6914"))
                benefitRow(icon: "shield.checkmark.fill", text: "\"Verified in person\" badge — highest trust level")
                benefitRow(icon: "person.3.fill", text: "Access to campus mixer events")
                benefitRow(icon: "ticket.fill", text: "Premium day pass at partner events")
            }
        }
    }

    // MARK: - Event Code

    private var codeContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .info } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "8B6914"))
                }
                Spacer()
            }

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 44)).foregroundColor(Color(hex: "8B6914"))

            VStack(spacing: 8) {
                Text("Enter Event Code").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Enter the code displayed at your campus verification booth or received after scanning the QR code.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Image(systemName: "ticket.fill").foregroundColor(Color(hex: "B8962A"))
                TextField("CAMPUS-XXXX", text: $eventCode)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
            }
            .padding(16).background(Color(hex: "FFF9EE"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "8B6914").opacity(0.2), lineWidth: 1))

            Button { verifyEventCode() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Verifying..." : "Verify Code").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "8B6914"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(eventCode.count < 4 || isSubmitting)
            .opacity(eventCode.count < 4 ? 0.6 : 1)
        }
    }

    // MARK: - Network Check

    private var networkContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .info } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A90D9"))
                }
                Spacer()
            }

            if isCheckingNetwork {
                ProgressView().scaleEffect(1.5).tint(Color(hex: "4A90D9"))
                    .padding(.top, 16)
                Text("Checking campus network...").font(.title3.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("We're checking if you're connected to a known campus Wi-Fi network.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            } else if networkCheckResult == "on_campus" {
                Image(systemName: "wifi.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "4A90D9"))
                Text("On Campus Detected").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

                if !verifiedUniversity.isEmpty {
                    Text(verifiedUniversity).font(.subheadline.bold()).foregroundColor(Color(hex: "4A90D9"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(hex: "4A90D9").opacity(0.1)).clipShape(Capsule())
                }

                Text("We detected you're on a campus network. This has been recorded as a supplemental verification signal. For a full verified badge, complete another verification method.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                Button { dismiss() } label: {
                    Text("Got it").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "4A90D9"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Image(systemName: "wifi.slash").font(.system(size: 64)).foregroundColor(Color(hex: "FF8A9E"))
                Text("Not on Campus Network").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("We couldn't detect a known campus Wi-Fi network. Make sure you're connected to your university's Wi-Fi and try again, or use another verification method.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                Button {
                    isCheckingNetwork = true; networkCheckResult = nil
                    checkCampusNetwork()
                } label: {
                    Text("Retry").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "4A90D9"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button { withAnimation { step = .info } } label: {
                    Text("Try another method").font(.subheadline).foregroundColor(Color(hex: "4A90D9"))
                }
            }
        }
    }

    // MARK: - Result

    private var resultContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "8B6914"))
            Text("Verified in Person!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            if !verifiedEventName.isEmpty {
                Text(verifiedEventName).font(.caption.bold()).foregroundColor(Color(hex: "8B6914"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "8B6914").opacity(0.1)).clipShape(Capsule())
            }

            if !verifiedUniversity.isEmpty {
                Text(verifiedUniversity).font(.subheadline).foregroundColor(Color(hex: "666666"))
            }

            Text("Your student status has been verified at a campus event. You now have a \"Verified in person\" badge — the highest trust level.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            Button { dismiss() } label: {
                Text("Continue").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "8B6914"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Helpers

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(Color(hex: "8B6914")).frame(width: 20)
            Text(text).font(.caption).foregroundColor(Color(hex: "555555"))
        }
    }

    // MARK: - API

    private func verifyEventCode() {
        isSubmitting = true
        Task {
            do {
                let body: [String: Any] = ["event_code": eventCode]
                let result: CampusEventVerificationResponse = try await APIService.shared.post(
                    path: "/student/verify-campus-event", body: body)
                if result.verified == true {
                    verifiedUniversity = result.universityName ?? ""
                    verifiedEventName = result.eventName ?? ""
                    await auth.refreshProfile()
                    withAnimation { step = .result }
                } else {
                    alertMessage = result.message ?? "Invalid event code. Please check and try again."
                    showAlert = true
                }
            } catch {
                alertMessage = "Verification failed. Please try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func checkCampusNetwork() {
        isCheckingNetwork = true
        Task {
            do {
                struct NetworkCheckResponse: Codable {
                    let onCampus: Bool?
                    let universityName: String?
                    let ipRange: String?
                    enum CodingKeys: String, CodingKey {
                        case onCampus = "on_campus"
                        case universityName = "university_name"
                        case ipRange = "ip_range"
                    }
                }
                let result: NetworkCheckResponse = try await APIService.shared.get(
                    path: "/student/campus-network-check")
                if result.onCampus == true {
                    verifiedUniversity = result.universityName ?? ""
                    networkCheckResult = "on_campus"
                } else {
                    networkCheckResult = "off_campus"
                }
            } catch {
                networkCheckResult = "off_campus"
            }
            isCheckingNetwork = false
        }
    }
}

#Preview {
    NavigationStack {
        CampusVerificationView()
            .environmentObject(AuthManager())
    }
}
