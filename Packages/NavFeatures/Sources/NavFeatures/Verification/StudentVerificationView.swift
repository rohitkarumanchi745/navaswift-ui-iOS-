import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct StudentVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case methodPicker, eduEmail, instituteDomain, otp, verified }

    @State private var step: Step = .methodPicker
    @State private var email = ""
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @State private var isSubmitting = false
    @State private var universityName = ""
    @State private var verificationMethod = ""
    @State private var resendTimer = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Int?

    // Institute domain search
    @State private var domainSearchText = ""
    @State private var matchedDomains: [InstituteDomain] = []
    @State private var selectedDomain: InstituteDomain? = nil

    private let benefits = [
        ("dollarsign.circle.fill", "Discounted premium plans"),
        ("sparkles", "Student-only events"),
        ("graduationcap.fill", "Verified student badge"),
        ("person.2.fill", "Connect with college students"),
    ]

    private var isValidEduEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.edu(\.[a-z]{2})?$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var isValidDomainEmail: Bool {
        guard let domain = selectedDomain else { return false }
        return email.lowercased().hasSuffix("@\(domain.domain)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 30)

                VStack(spacing: 24) {
                    switch step {
                    case .methodPicker: methodPickerContent
                    case .eduEmail: eduEmailContent
                    case .instituteDomain: instituteDomainContent
                    case .otp: otpContent
                    case .verified: verifiedContent
                    }
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

    // MARK: - Method Picker

    private var methodPickerContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "graduationcap.fill").font(.system(size: 44)).foregroundColor(Color(hex: "5F7A66"))

            VStack(spacing: 8) {
                Text("Verify Student Status").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Choose how you'd like to verify. Different methods provide different trust badges.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                // .edu Email (inline)
                methodCard(
                    icon: "envelope.fill",
                    title: ".edu Email",
                    subtitle: "Verify with your .edu email address",
                    badge: "Verified by email",
                    color: Color(hex: "5F7A66")
                ) { withAnimation { step = .eduEmail } }

                // Institute domain (inline)
                methodCard(
                    icon: "building.2.fill",
                    title: "Institute Email",
                    subtitle: "Non-.edu college domains (e.g. @college.ac.in)",
                    badge: "Verified by email",
                    color: Color(hex: "4A6FA5")
                ) { withAnimation { step = .instituteDomain } }

                // Student ID + Selfie (navigation)
                NavigationLink {
                    StudentIDVerificationView()
                } label: {
                    methodCardLabel(
                        icon: "person.text.rectangle.fill",
                        title: "Student ID + Selfie",
                        subtitle: "Photo of ID card + liveness selfie check",
                        badge: "Verified by document",
                        color: Color(hex: "7B8B4E")
                    )
                }

                // Enrollment Proof (navigation)
                NavigationLink {
                    EnrollmentProofView()
                } label: {
                    methodCardLabel(
                        icon: "doc.text.fill",
                        title: "Enrollment Proof",
                        subtitle: "Upload enrollment letter or fee receipt",
                        badge: "Verified by document",
                        color: Color(hex: "8B6914")
                    )
                }

                // Campus Event (navigation)
                NavigationLink {
                    CampusVerificationView()
                } label: {
                    methodCardLabel(
                        icon: "qrcode.viewfinder",
                        title: "Campus Event / Network",
                        subtitle: "QR code at event booth or campus Wi-Fi check",
                        badge: "Verified in person",
                        color: Color(hex: "9B5DE5")
                    )
                }
            }

            Divider().padding(.top, 4)

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

    // MARK: - Method Card

    private func methodCard(icon: String, title: String, subtitle: String, badge: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            methodCardLabel(icon: icon, title: title, subtitle: subtitle, badge: badge, color: color)
        }
    }

    private func methodCardLabel(icon: String, title: String, subtitle: String, badge: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "1F1F1F"))
                Text(subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "888888")).lineLimit(1)
                Text(badge).font(.system(size: 10, weight: .medium)).foregroundColor(color)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "CCCCCC"))
        }
        .padding(12)
        .background(Color(hex: "FAFAFA"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1))
    }

    // MARK: - .edu Email Step

    private var eduEmailContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .methodPicker; email = "" } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "5F7A66"))
                }
                Spacer()
            }

            Image(systemName: "envelope.fill").font(.system(size: 44)).foregroundColor(Color(hex: "5F7A66"))
            Text(".edu Email Verification").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Enter your university email (.edu) to verify your student status.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill").foregroundColor(Color(hex: "7D8B82"))
                TextField("you@university.edu", text: $email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress).autocapitalization(.none)
            }
            .padding(16).background(Color(hex: "F4E7DD"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                verificationMethod = "edu_email"
                sendVerificationCode()
            } label: {
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
        }
    }

    // MARK: - Institute Domain Step

    private var instituteDomainContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .methodPicker; email = ""; domainSearchText = ""; matchedDomains = []; selectedDomain = nil } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Image(systemName: "building.2.fill").font(.system(size: 44)).foregroundColor(Color(hex: "4A6FA5"))
            Text("Institute Email").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Search for your institute to find accepted email domains (e.g. @college.ac.in, @univ.in).")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            // Institute search
            VStack(alignment: .leading, spacing: 8) {
                Text("Search your institute").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "7A9FBF"))
                    TextField("Type institute name...", text: $domainSearchText)
                }
                .padding(14).background(Color(hex: "E8EFF7"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: domainSearchText) { _, newValue in
                    if newValue.count >= 3 { searchInstituteDomains() }
                }

                // Results
                if !matchedDomains.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(matchedDomains) { domain in
                            Button {
                                selectedDomain = domain
                                universityName = domain.instituteName
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedDomain?.id == domain.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedDomain?.id == domain.id ? Color(hex: "4A6FA5") : Color(hex: "CCCCCC"))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(domain.instituteName).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "1F1F1F"))
                                        Text("@\(domain.domain)").font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(selectedDomain?.id == domain.id ? Color(hex: "4A6FA5").opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(8).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Email input (shown after selecting domain)
            if let domain = selectedDomain {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter your \(domain.instituteName) email").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill").foregroundColor(Color(hex: "7A9FBF"))
                        TextField("you@\(domain.domain)", text: $email)
                            .keyboardType(.emailAddress).textContentType(.emailAddress).autocapitalization(.none)
                    }
                    .padding(14).background(Color(hex: "E8EFF7"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if !email.isEmpty && !isValidDomainEmail {
                        Text("Email must end with @\(domain.domain)")
                            .font(.caption).foregroundColor(AppColors.error)
                    }
                }

                Button {
                    verificationMethod = "institute_domain"
                    sendVerificationCode()
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Sending..." : "Send Code").font(.headline)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "4A6FA5"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(!isValidDomainEmail || isSubmitting)
                .opacity(!isValidDomainEmail ? 0.6 : 1)
            }
        }
    }

    // MARK: - OTP Step

    private var otpContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button {
                    withAnimation {
                        step = verificationMethod == "institute_domain" ? .instituteDomain : .eduEmail
                    }
                } label: {
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

    // MARK: - Verified

    private var verifiedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.green)
            Text("Student Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            if !universityName.isEmpty {
                VStack(spacing: 4) {
                    Text(universityName).font(.subheadline).foregroundColor(Color(hex: "5F7A66"))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "5F7A66").opacity(0.1)).clipShape(Capsule())

                    if !verificationMethod.isEmpty {
                        let method = StudentVerificationMethod(rawValue: verificationMethod)
                        Text(method?.badgeLabel ?? "Verified")
                            .font(.caption).foregroundColor(Color(hex: "888888"))
                    }
                }
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

    // MARK: - API

    private func loadStudentStatus() async {
        if auth.user?.isStudentVerified == true {
            verificationMethod = auth.user?.studentVerificationMethod ?? ""
            step = .verified
            return
        }
        do {
            let result: StudentVerificationStatusResponse = try await APIService.shared.get(path: "/student/status")
            if result.isVerified == true {
                universityName = result.universityName ?? ""
                verificationMethod = result.method ?? ""
                step = .verified
            }
        } catch {}
    }

    private func searchInstituteDomains() {
        Task {
            do {
                let result: InstituteDomainSearchResponse = try await APIService.shared.get(
                    path: "/student/institute-domains?q=\(domainSearchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domainSearchText)")
                matchedDomains = result.domains
            } catch {
                matchedDomains = []
            }
        }
    }

    private func sendVerificationCode() {
        isSubmitting = true
        Task {
            do {
                struct VerifyResponse: Codable { let message: String?; let university_name: String? }
                let result: VerifyResponse = try await APIService.shared.post(
                    path: "/student/verify", body: ["email": email, "method": verificationMethod])
                universityName = result.university_name ?? universityName
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
                var body: [String: Any] = ["email": email, "otp": otpString, "method": verificationMethod]
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
