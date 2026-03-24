import SwiftUI
import PhotosUI
import NavCore
import NavNetworking
import NavServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AlumniVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case info, methodPicker, alumniEmail, otp, degreeUpload, linkedin, submitted, verified }
    enum VerifyMethod: String { case alumniEmail, degree, linkedin }

    @State private var step: Step = .info
    @State private var selectedMethod: VerifyMethod? = nil
    @State private var email = ""
    @State private var universityName = ""
    @State private var graduationYear = ""
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @State private var linkedinURL = ""
    @State private var documentImage: PlatformImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isSubmitting = false
    @State private var resendTimer = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var universityResults: [UniversitySearchResult] = []
    @State private var showUniversityResults = false
    @State private var universitySearchTask: Task<Void, Never>?
    @FocusState private var focusedField: Int?
    @FocusState private var isUniversityFocused: Bool

    private let benefits = [
        ("person.2.fill", "Connect with fellow alumni"),
        ("graduationcap.fill", "Verified alumni badge"),
        ("calendar.badge.clock", "Class year search filters"),
        ("party.popper.fill", "Alumni mixer invitations"),
    ]

    private let yearOptions = (1970...2030).reversed().map { String($0) }

    private var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var isValidLinkedInURL: Bool {
        linkedinURL.lowercased().contains("linkedin.com/in/") && linkedinURL.count > 25
    }

    @ViewBuilder
    private var documentImageView: some View {
        if let image = documentImage {
            #if canImport(UIKit)
            Image(uiImage: image).resizable().scaledToFill()
            #elseif canImport(AppKit)
            Image(nsImage: image).resizable().scaledToFill()
            #endif
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                VStack(spacing: 24) {
                    switch step {
                    case .verified: verifiedContent
                    case .info: infoContent
                    case .methodPicker: methodPickerContent
                    case .alumniEmail: emailContent
                    case .otp: otpContent
                    case .degreeUpload: degreeUploadContent
                    case .linkedin: linkedinContent
                    case .submitted: submittedContent
                    }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "D1E8F3"))
        .navigationTitle("Alumni Verification").navigationBarTitleDisplayMode(.inline)
        .alert("Alumni Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
        .task { await loadAlumniStatus() }
    }

    // MARK: - Verified
    private var verifiedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "4A90D9"))
            Text("Alumni Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            if !universityName.isEmpty {
                VStack(spacing: 4) {
                    Text(universityName).font(.subheadline.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    if !graduationYear.isEmpty {
                        Text("Class of \(graduationYear)").font(.caption).foregroundColor(Color(hex: "4A6FA5").opacity(0.7))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
            }

            Text("You now have access to alumni networking features and class year filters.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            Button { dismiss() } label: {
                Text("Continue").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "4A6FA5"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Info Step
    private var infoContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns.fill").font(.system(size: 48)).foregroundColor(Color(hex: "4A6FA5"))
            Text("Alumni Network").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Verify your alumni status to unlock networking features with your university community.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("University").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        TextField("Search your university...", text: $universityName)
                            .padding(14).background(Color(hex: "E8EFF7"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .focused($isUniversityFocused)
                            .autocorrectionDisabled()
                            .onChange(of: universityName) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                universitySearchTask?.cancel()
                                if trimmed.isEmpty {
                                    if isUniversityFocused {
                                        universityResults = []
                                        showUniversityResults = true
                                    } else {
                                        universityResults = []
                                        showUniversityResults = false
                                    }
                                    return
                                }
                                showUniversityResults = true
                                universitySearchTask = Task {
                                    try? await Task.sleep(for: .milliseconds(200))
                                    guard !Task.isCancelled else { return }
                                    await searchUniversities(query: trimmed)
                                }
                            }
                            .onChange(of: isUniversityFocused) { _, focused in
                                if focused && universityName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    universityResults = []
                                    showUniversityResults = true
                                }
                            }
                    }

                    if showUniversityResults && !universityName.trimmingCharacters(in: .whitespaces).isEmpty {
                        VStack(spacing: 0) {
                            if !universityResults.isEmpty {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(universityResults.prefix(6)) { uni in
                                            Button {
                                                universityName = uni.name
                                                showUniversityResults = false
                                                isUniversityFocused = false
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "graduationcap.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color(hex: "4A6FA5"))
                                                        .frame(width: 24)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(uni.name)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(Color(hex: "1F1F1F"))
                                                            .lineLimit(1)
                                                        if let city = uni.city {
                                                            Text(city + (uni.country.map { ", \($0)" } ?? ""))
                                                                .font(.system(size: 11))
                                                                .foregroundColor(Color(hex: "999999"))
                                                        }
                                                    }
                                                    Spacer()
                                                    if let tier = uni.tier, !tier.isEmpty {
                                                        Text(tier)
                                                            .font(.system(size: 9, weight: .medium))
                                                            .foregroundColor(Color(hex: "4A6FA5"))
                                                            .padding(.horizontal, 6).padding(.vertical, 3)
                                                            .background(Color(hex: "4A6FA5").opacity(0.1))
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                .padding(.horizontal, 12).padding(.vertical, 10)
                                            }
                                            Divider().padding(.leading, 46)
                                        }
                                    }
                                }
                                .frame(maxHeight: 180)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "999999"))
                                    Text("No matching universities found")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "999999"))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 12)
                                Divider()
                            }

                            // "Use custom name" button
                            Button {
                                showUniversityResults = false
                                isUniversityFocused = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "4A6FA5"))
                                    Text("Use \"\(universityName.trimmingCharacters(in: .whitespaces))\"")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "4A6FA5"))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 12)
                                .background(Color(hex: "4A6FA5").opacity(0.05))
                            }
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "4A6FA5").opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        .padding(.top, 52)
                        .zIndex(10)
                    }
                }

                Text("Graduation Year").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                Picker("Graduation Year", selection: $graduationYear) {
                    Text("Select year").tag("")
                    ForEach(yearOptions, id: \.self) { year in
                        Text(year).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .background(Color(hex: "E8EFF7"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                withAnimation { step = .methodPicker }
            } label: {
                Text("Continue").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "4A6FA5"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(universityName.isEmpty || graduationYear.isEmpty)
            .opacity(universityName.isEmpty || graduationYear.isEmpty ? 0.6 : 1)

            Divider().padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(benefits, id: \.1) { benefit in
                    HStack(spacing: 10) {
                        Image(systemName: benefit.0).foregroundColor(Color(hex: "4A6FA5")).frame(width: 24)
                        Text(benefit.1).font(.subheadline).foregroundColor(Color(hex: "333333"))
                    }
                }
            }
        }
    }

    // MARK: - Method Picker
    private var methodPickerContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .info } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Image(systemName: "checkmark.shield.fill").font(.system(size: 44)).foregroundColor(Color(hex: "4A6FA5"))
            Text("Choose Verification").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Select how you'd like to verify your alumni status at \(universityName).")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            VStack(spacing: 12) {
                methodCard(
                    icon: "envelope.fill",
                    title: "Alumni Email",
                    description: "Use your alumni or university email address (.edu)",
                    tag: "Fastest",
                    tagColor: Color(hex: "4ECDC4"),
                    method: .alumniEmail
                )

                methodCard(
                    icon: "doc.text.fill",
                    title: "Degree / Diploma",
                    description: "Upload a photo of your degree certificate or transcript",
                    tag: "Most common",
                    tagColor: Color(hex: "4A6FA5"),
                    method: .degree
                )

                methodCard(
                    icon: "link",
                    title: "LinkedIn Profile",
                    description: "Link your LinkedIn showing education at this university",
                    tag: "Manual review",
                    tagColor: Color(hex: "FFB347"),
                    method: .linkedin
                )
            }
        }
    }

    private func methodCard(icon: String, title: String, description: String, tag: String, tagColor: Color, method: VerifyMethod) -> some View {
        Button {
            selectedMethod = method
            withAnimation {
                switch method {
                case .alumniEmail: step = .alumniEmail
                case .degree: step = .degreeUpload
                case .linkedin: step = .linkedin
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(tagColor)
                    .frame(width: 40, height: 40)
                    .background(tagColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "1F1F1F"))
                        Text(tag).font(.system(size: 10, weight: .bold))
                            .foregroundColor(tagColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(tagColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(description).font(.system(size: 12))
                        .foregroundColor(Color(hex: "888888"))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "CCCCCC"))
            }
            .padding(14)
            .background(Color(hex: "F8F9FA"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "E8EFF7"), lineWidth: 1))
        }
    }

    // MARK: - Email Step
    private var emailContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .methodPicker } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Text("Verify Email").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Enter your alumni or university email to verify your identity.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            if !universityName.isEmpty {
                Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill").foregroundColor(Color(hex: "7A9FBF"))
                TextField("you@alumni.university.edu", text: $email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress).autocapitalization(.none)
            }
            .padding(16).background(Color(hex: "E8EFF7"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button { sendVerificationCode() } label: {
                HStack {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Sending..." : "Send Code").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "4A6FA5"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(!isValidEmail || isSubmitting)
            .opacity(!isValidEmail ? 0.6 : 1)

            if !email.isEmpty && !isValidEmail {
                Text("Please enter a valid email address")
                    .font(.caption).foregroundColor(AppColors.error)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "4A6FA5"))
                Text("Don't have an alumni email? Go back and choose Degree Upload or LinkedIn instead.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
            }
            .padding(12).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - OTP Step
    private var otpContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .alumniEmail } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Text("Enter Code").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("We sent a 6-digit code to \(email)")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: $otp[index])
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold)).frame(height: 56)
                        .background(otp[index].isEmpty ? Color(hex: "E8EFF7") : Color(hex: "D4E3F2"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(otp[index].isEmpty ? .clear : Color(hex: "4A6FA5"), lineWidth: 2))
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
                .background(Color(hex: "4A6FA5"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(otp.contains("") || isSubmitting)
            .opacity(otp.contains("") ? 0.6 : 1)

            Button {
                if resendTimer == 0 { sendVerificationCode() }
            } label: {
                Text(resendTimer > 0 ? "Resend in \(resendTimer)s" : "Resend Code")
                    .font(.subheadline)
                    .foregroundColor(resendTimer > 0 ? Color(hex: "9A9A9A") : Color(hex: "4A6FA5"))
            }
            .disabled(resendTimer > 0)
        }
    }

    // MARK: - Degree Upload Step
    private var degreeUploadContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .methodPicker } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Image(systemName: "doc.text.fill")
                .font(.system(size: 44)).foregroundColor(Color(hex: "4A6FA5"))

            VStack(spacing: 8) {
                Text("Upload Degree / Diploma").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Upload a photo of your degree certificate, diploma, or official transcript from \(universityName).")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            if !universityName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill").font(.system(size: 11)).foregroundColor(Color(hex: "4A6FA5"))
                    Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    if !graduationYear.isEmpty {
                        Text("· Class of \(graduationYear)").font(.caption).foregroundColor(Color(hex: "4A6FA5").opacity(0.7))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color(hex: "F0F4F8"))
                        .frame(height: documentImage == nil ? 180 : 240)
                    if documentImage != nil {
                        documentImageView.frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.viewfinder.fill")
                                .font(.system(size: 36)).foregroundColor(Color(hex: "7A9FBF"))
                            Text("Tap to upload document").font(.subheadline).foregroundColor(Color(hex: "7A9FBF"))
                            Text("Degree, diploma, or transcript").font(.caption).foregroundColor(Color(hex: "AAAAAA"))
                        }
                    }
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = decodeImageData(data) {
                        documentImage = image
                    }
                }
            }

            // Privacy note
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "4A6FA5"))
                Text("Your document is encrypted and stored securely. We verify only your name, university, and graduation year. The original is deleted after review.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
            }
            .padding(12).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 10))

            Button { submitDegreeDocument() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Submitting..." : "Submit for Review").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "4A6FA5"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(documentImage == nil || isSubmitting)
            .opacity(documentImage == nil ? 0.6 : 1)
        }
    }

    // MARK: - LinkedIn Step
    private var linkedinContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .methodPicker } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "4A6FA5"))
                }
                Spacer()
            }

            Image(systemName: "link.circle.fill")
                .font(.system(size: 44)).foregroundColor(Color(hex: "0077B5"))

            VStack(spacing: 8) {
                Text("LinkedIn Verification").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Link your LinkedIn profile to verify your alumni status. We'll check that your education section lists \(universityName).")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            if !universityName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill").font(.system(size: 11)).foregroundColor(Color(hex: "4A6FA5"))
                    Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    if !graduationYear.isEmpty {
                        Text("· Class of \(graduationYear)").font(.caption).foregroundColor(Color(hex: "4A6FA5").opacity(0.7))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Image(systemName: "link").foregroundColor(Color(hex: "0077B5"))
                TextField("https://linkedin.com/in/yourprofile", text: $linkedinURL)
                    .keyboardType(.URL).textContentType(.URL).autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(16).background(Color(hex: "E8EFF7"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Checklist
            VStack(alignment: .leading, spacing: 10) {
                Text("Before submitting, make sure:").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                checklistItem("Your profile is set to public")
                checklistItem("Education section is visible")
                checklistItem("\(universityName) is listed under education")
            }
            .padding(14).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 12))

            // Review warning
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "FFB347"))
                Text("LinkedIn verification requires manual review. This typically takes up to 24 hours.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
            }
            .padding(12).background(Color(hex: "FFF8F0")).clipShape(RoundedRectangle(cornerRadius: 10))

            Button { submitLinkedIn() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Submitting..." : "Submit for Review").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "4A6FA5"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(!isValidLinkedInURL || isSubmitting)
            .opacity(!isValidLinkedInURL ? 0.6 : 1)

            if !linkedinURL.isEmpty && !isValidLinkedInURL {
                Text("Please enter a valid LinkedIn profile URL")
                    .font(.caption).foregroundColor(AppColors.error)
            }
        }
    }

    private func checklistItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "4ECDC4"))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "555555"))
        }
    }

    // MARK: - Submitted (Pending Review)
    private var submittedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill").font(.system(size: 64)).foregroundColor(Color(hex: "FFB347"))
            Text("Submitted for Review").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

            let methodName: String = {
                switch selectedMethod {
                case .degree: return "degree document"
                case .linkedin: return "LinkedIn profile"
                default: return "verification"
                }
            }()

            Text("Your \(methodName) has been submitted. A reviewer will verify it within 24 hours. You'll receive a notification once your alumni status is confirmed.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

            if !universityName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill").font(.system(size: 11)).foregroundColor(Color(hex: "4A6FA5"))
                    Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                    if !graduationYear.isEmpty {
                        Text("· Class of \(graduationYear)").font(.caption).foregroundColor(Color(hex: "4A6FA5").opacity(0.7))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
            }

            Button { dismiss() } label: {
                Text("Got it").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "FFB347"))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - API

    private func loadAlumniStatus() async {
        if auth.user?.isAlumniVerified == true { step = .verified; return }
        do {
            struct StatusResponse: Codable { let is_verified: Bool?; let university_name: String?; let graduation_year: Int? }
            let result: StatusResponse = try await APIService.shared.get(path: "/alumni/status")
            if result.is_verified == true {
                universityName = result.university_name ?? ""
                if let year = result.graduation_year { graduationYear = String(year) }
                step = .verified
            }
        } catch {}
    }

    private func sendVerificationCode() {
        isSubmitting = true
        Task {
            do {
                struct VerifyResponse: Codable { let message: String? }
                let body: [String: Any] = [
                    "email": email,
                    "university_name": universityName,
                    "graduation_year": Int(graduationYear) ?? 0
                ]
                let _: VerifyResponse = try await APIService.shared.post(path: "/alumni/verify", body: body)
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
                struct OtpResponse: Codable { let verified: Bool? }
                let body: [String: Any] = [
                    "email": email, "otp": otpString,
                    "university_name": universityName,
                    "graduation_year": Int(graduationYear) ?? 0
                ]
                let _: OtpResponse = try await APIService.shared.post(path: "/alumni/verify-otp", body: body)
                await auth.refreshProfile()
                withAnimation { step = .verified }
            } catch {
                alertMessage = "Invalid code. Please try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func submitDegreeDocument() {
        guard let image = documentImage else { return }
        isSubmitting = true

        Task {
            do {
                guard let imageData = imageToJPEGData(image, compressionQuality: 0.85) else {
                    alertMessage = "Could not process image."
                    isSubmitting = false; showAlert = true; return
                }

                let result: DocumentVerificationResponse = try await APIService.shared.multipartUpload(
                    path: "/alumni/verify-degree",
                    fileData: imageData,
                    fileName: "alumni-degree.jpg",
                    mimeType: "image/jpeg",
                    fileField: "document",
                    fields: [
                        "university_name": universityName,
                        "graduation_year": graduationYear
                    ])

                if result.status == "auto_approved" {
                    await auth.refreshProfile()
                    withAnimation { step = .verified }
                } else {
                    withAnimation { step = .submitted }
                }
            } catch {
                alertMessage = "Upload failed: \(error.localizedDescription)"
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func submitLinkedIn() {
        isSubmitting = true
        Task {
            do {
                struct LinkedInResponse: Codable { let status: String? }
                let body: [String: Any] = [
                    "linkedin_url": linkedinURL,
                    "university_name": universityName,
                    "graduation_year": Int(graduationYear) ?? 0
                ]
                let _: LinkedInResponse = try await APIService.shared.post(path: "/alumni/verify-linkedin", body: body)
                withAnimation { step = .submitted }
            } catch {
                alertMessage = "Failed to submit. Please check your URL and try again."
                showAlert = true
            }
            isSubmitting = false
        }
    }

    private func searchUniversities(query: String) async {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        do {
            let response: UniversitySearchResponse = try await APIService.shared.get(
                path: "/universities/search?q=\(encoded)&limit=8"
            )
            if universityName.lowercased().contains(query.lowercased().prefix(3)) {
                universityResults = response.universities
            }
        } catch {
            universityResults = []
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
        AlumniVerificationView()
            .environmentObject(AuthManager())
    }
}
