import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct StudentVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case email, otp, verified }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @State private var isSubmitting = false
    @State private var universityName = ""
    @State private var resendTimer = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Int?

    private let benefits = [
        ("dollarsign.circle.fill", "Discounted premium plans"),
        ("sparkles", "Student-only events"),
        ("graduationcap.fill", "Verified student badge"),
        ("person.2.fill", "Connect with college students"),
    ]

    private var isValidEduEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.edu$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                VStack(spacing: 24) {
                    if step == .verified { verifiedContent }
                    else if step == .email { emailContent }
                    else { otpContent }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Student Verification").navigationBarTitleDisplayMode(.inline)
        .alert("Student Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
        .task { await loadStudentStatus() }
    }

    // MARK: - Verified
    private var verifiedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.green)
            Text("Student Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            if !universityName.isEmpty {
                Text(universityName).font(.subheadline).foregroundColor(Color(hex: "5F7A66"))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(hex: "5F7A66").opacity(0.1)).clipShape(Capsule())
            }

            Text("You now have access to student discounts and exclusive features.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            Button { dismiss() } label: {
                Text("Continue").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "5F7A66"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Email Step
    private var emailContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "graduationcap.fill").font(.system(size: 48)).foregroundColor(Color(hex: "5F7A66"))
            Text("Student Benefits").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Enter your university email (.edu) to verify your student status.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill").foregroundColor(Color(hex: "7D8B82"))
                TextField("you@university.edu", text: $email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress).autocapitalization(.none)
            }
            .padding(16).background(Color(hex: "F4E7DD"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button { sendVerificationCode() } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Sending..." : "Send Code").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "5F7A66"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(!isValidEduEmail || isSubmitting)
            .opacity(!isValidEduEmail ? 0.6 : 1)

            if !email.isEmpty && !isValidEduEmail {
                Text("Please enter a valid .edu email address")
                    .font(.caption).foregroundColor(AppColors.error)
            }

            Divider().padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(benefits, id: \.1) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: benefit.0).foregroundColor(Color(hex: "5F7A66")).frame(width: 24)
                        Text(benefit.1).font(.subheadline).foregroundColor(Color(hex: "333333"))
                    }
                }
            }
        }
    }

    // MARK: - OTP Step
    private var otpContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .email } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "5F7A66"))
                }
                Spacer()
            }

            Text("Enter Code").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("We sent a 6-digit code to \(email)")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            if !universityName.isEmpty {
                Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "5F7A66"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "5F7A66").opacity(0.1)).clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: $otp[index])
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold)).frame(height: 56)
                        .background(otp[index].isEmpty ? Color(hex: "F4E7DD") : Color(hex: "E8D9CE"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(otp[index].isEmpty ? .clear : Color(hex: "5F7A66"), lineWidth: 2))
                        .focused($focusedField, equals: index)
                        .onChange(of: otp[index]) { _, newValue in
                            if newValue.count > 1 { otp[index] = String(newValue.last!) }
                            if !newValue.isEmpty && index < 5 { focusedField = index + 1 }
                        }
                }
            }

            Button { verifyOtp() } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Verifying..." : "Verify").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "5F7A66"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(otp.contains("") || isSubmitting)
            .opacity(otp.contains("") ? 0.6 : 1)

            Button {
                if resendTimer == 0 { sendVerificationCode() }
            } label: {
                Text(resendTimer > 0 ? "Resend in \(resendTimer)s" : "Resend Code")
                    .font(.subheadline)
                    .foregroundColor(resendTimer > 0 ? Color(hex: "9A9A9A") : Color(hex: "5F7A66"))
            }
            .disabled(resendTimer > 0)
        }
    }

    // MARK: - API

    private func loadStudentStatus() async {
        if auth.user?.isStudentVerified == true { step = .verified; return }
        do {
            struct StatusResponse: Codable { let is_verified: Bool?; let university_name: String?; let email: String? }
            let result: StatusResponse = try await APIService.shared.get(path: "/student/status")
            if result.is_verified == true {
                universityName = result.university_name ?? ""
                step = .verified
            }
        } catch {}
    }

    private func sendVerificationCode() {
        isSubmitting = true
        Task {
            do {
                struct VerifyResponse: Codable { let message: String?; let university_name: String? }
                let result: VerifyResponse = try await APIService.shared.post(
                    path: "/student/verify", body: ["email": email])
                universityName = result.university_name ?? ""
                withAnimation { step = .otp }
                startResendTimer()
            } catch {
                alertMessage = "Failed to send code. Please check your email and try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func verifyOtp() {
        isSubmitting = true
        Task {
            do {
                let otpString = otp.joined()
                struct OtpResponse: Codable { let verified: Bool?; let university_name: String? }
                var body: [String: Any] = ["email": email, "otp": otpString]
                if !universityName.isEmpty { body["university_name"] = universityName }
                let _: OtpResponse = try await APIService.shared.post(path: "/student/verify-otp", body: body)
                await auth.refreshProfile()
                withAnimation { step = .verified }
            } catch {
                alertMessage = "Invalid code. Please try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func startResendTimer() {
        resendTimer = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendTimer > 0 { resendTimer -= 1 }
            else { timer.invalidate() }
        }
    }
}

#Preview {
    NavigationStack {
        StudentVerificationView()
            .environmentObject(AuthManager())
    }
}
