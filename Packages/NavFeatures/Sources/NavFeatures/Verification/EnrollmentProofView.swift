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

struct EnrollmentProofView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case upload, submitted }

    @State private var step: Step = .upload
    @State private var documentImage: PlatformImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var docType: String = "enrollment_letter"
    @State private var universityName = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var resultStatus = ""  // "pending_review", "auto_approved", "rejected"

    private let docTypes = [
        ("enrollment_letter", "Enrollment / Admission Letter"),
        ("fee_receipt", "Fee Receipt (current term)"),
        ("bonafide", "Bonafide Certificate"),
    ]

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
                Spacer().frame(height: 30)

                VStack(spacing: 24) {
                    switch step {
                    case .upload: uploadContent
                    case .submitted: submittedContent
                    }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "E3E8F0"))
        .navigationTitle("Enrollment Proof").navigationBarTitleDisplayMode(.inline)
        .alert("Enrollment Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
    }

    // MARK: - Upload Content

    private var uploadContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 44)).foregroundColor(Color(hex: "4A6FA5"))

            VStack(spacing: 8) {
                Text("Upload Enrollment Proof").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Upload an official document proving your current enrollment. We accept admission letters, fee receipts, or bonafide certificates.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            // Document type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Type").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                ForEach(docTypes, id: \.0) { type in
                    Button {
                        docType = type.0
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: docType == type.0 ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(docType == type.0 ? Color(hex: "4A6FA5") : Color(hex: "CCCCCC"))
                                .font(.system(size: 18))
                            Text(type.1).font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "333333"))
                            Spacer()
                        }
                        .padding(12)
                        .background(docType == type.0 ? Color(hex: "4A6FA5").opacity(0.08) : Color(hex: "F8F9FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // University name
            VStack(alignment: .leading, spacing: 6) {
                Text("University / Institute").font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                TextField("Enter your institute name", text: $universityName)
                    .padding(14).background(Color(hex: "F0F4F8"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Document capture
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
                            Text("Photo or scanned copy").font(.caption).foregroundColor(Color(hex: "AAAAAA"))
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
                Text("Your document is encrypted and stored securely. We extract only pass/fail status, institute name, and validity dates. The original is deleted after review.")
                    .font(.system(size: 11)).foregroundColor(Color(hex: "888888"))
            }
            .padding(12).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 10))

            Button { submitDocument() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Submitting..." : "Submit for Review").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "4A6FA5"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(documentImage == nil || universityName.isEmpty || isSubmitting)
            .opacity(documentImage == nil || universityName.isEmpty ? 0.6 : 1)
        }
    }

    // MARK: - Submitted Content

    private var submittedContent: some View {
        VStack(spacing: 20) {
            if resultStatus == "auto_approved" {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "4A6FA5"))
                Text("Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Your enrollment document was verified automatically. You now have a \"Verified by document\" badge.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            } else {
                Image(systemName: "clock.fill").font(.system(size: 64)).foregroundColor(Color(hex: "FFB347"))
                Text("Submitted for Review").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Your document has been submitted. A reviewer will verify it within 24 hours. You'll receive a notification once your status is updated.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                if !universityName.isEmpty {
                    Text(universityName).font(.caption.bold()).foregroundColor(Color(hex: "4A6FA5"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(hex: "4A6FA5").opacity(0.1)).clipShape(Capsule())
                }
            }

            Button { dismiss() } label: {
                Text(resultStatus == "auto_approved" ? "Continue" : "Got it")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(resultStatus == "auto_approved" ? Color(hex: "4A6FA5") : Color(hex: "FFB347"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - API

    private func submitDocument() {
        guard let image = documentImage else { return }
        isSubmitting = true

        Task {
            do {
                guard let imageData = imageToJPEGData(image, compressionQuality: 0.85) else {
                    alertMessage = "Could not process image."
                    isSubmitting = false; showAlert = true; return
                }

                let result: DocumentVerificationResponse = try await APIService.shared.multipartUpload(
                    path: "/student/verify-enrollment",
                    fileData: imageData,
                    fileName: "enrollment-doc.jpg",
                    mimeType: "image/jpeg",
                    fileField: "document",
                    fields: [
                        "doc_type": docType,
                        "university_name": universityName
                    ])

                resultStatus = result.status ?? "pending_review"
                if resultStatus == "auto_approved" {
                    await auth.refreshProfile()
                }
                withAnimation { step = .submitted }
            } catch {
                alertMessage = "Upload failed: \(error.localizedDescription)"
                showAlert = true
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        EnrollmentProofView()
            .environmentObject(AuthManager())
    }
}
