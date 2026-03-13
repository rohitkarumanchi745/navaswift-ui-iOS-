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

struct StudentIDVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    enum Step { case idCapture, selfieCapture, reviewing, result }

    @State private var step: Step = .idCapture
    @State private var idImage: PlatformImage? = nil
    @State private var selfieImage: PlatformImage? = nil
    @State private var selectedIdItem: PhotosPickerItem? = nil
    @State private var selectedSelfieItem: PhotosPickerItem? = nil
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var resultStatus: String = ""  // "auto_approved", "pending_review", "rejected"
    @State private var detectedName = ""
    @State private var detectedUniversity = ""

    @ViewBuilder
    private func imageView(_ image: PlatformImage?) -> some View {
        if let image {
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
                    // Progress indicator
                    progressBar

                    switch step {
                    case .idCapture: idCaptureContent
                    case .selfieCapture: selfieCaptureContent
                    case .reviewing: reviewingContent
                    case .result: resultContent
                    }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "E8F0E3"))
        .navigationTitle("Student ID Verification").navigationBarTitleDisplayMode(.inline)
        .alert("Verification", isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                let stepIndex: Int = {
                    switch step {
                    case .idCapture: return 0
                    case .selfieCapture: return 1
                    case .reviewing, .result: return 2
                    }
                }()
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= stepIndex ? Color(hex: "5F7A66") : Color(hex: "E0E0E0"))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: ID Capture

    private var idCaptureContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 44)).foregroundColor(Color(hex: "5F7A66"))

            VStack(spacing: 8) {
                Text("Upload Student ID").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Take a clear photo of your current student ID card. Make sure your name, institute, and validity are visible.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selectedIdItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color(hex: "F0F4ED")).frame(height: 200)
                    if idImage != nil {
                        imageView(idImage).frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.on.rectangle.fill")
                                .font(.system(size: 36)).foregroundColor(Color(hex: "7D8B82"))
                            Text("Tap to capture ID").font(.subheadline).foregroundColor(Color(hex: "7D8B82"))
                        }
                    }
                }
            }
            .onChange(of: selectedIdItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = decodeImageData(data) {
                        idImage = image
                    }
                }
            }

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "checkmark.circle.fill", text: "Ensure the full card is visible")
                tipRow(icon: "sun.max.fill", text: "Good lighting, no glare or shadows")
                tipRow(icon: "hand.raised.fill", text: "Hold steady — avoid blurriness")
            }
            .padding(14).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                withAnimation { step = .selfieCapture }
            } label: {
                Text("Next: Take Selfie").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(hex: "5F7A66"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(idImage == nil)
            .opacity(idImage == nil ? 0.6 : 1)
        }
    }

    // MARK: - Step 2: Selfie Capture

    private var selfieCaptureContent: some View {
        VStack(spacing: 20) {
            HStack {
                Button { withAnimation { step = .idCapture } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left"); Text("Back")
                    }.font(.subheadline).foregroundColor(Color(hex: "5F7A66"))
                }
                Spacer()
            }

            Image(systemName: "faceid")
                .font(.system(size: 44)).foregroundColor(Color(hex: "5F7A66"))

            VStack(spacing: 8) {
                Text("Liveness Selfie").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                Text("Take a selfie to confirm your identity. We'll compare it with the photo on your student ID.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selectedSelfieItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color(hex: "F0F4ED")).frame(height: 240)
                    if selfieImage != nil {
                        imageView(selfieImage).frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36)).foregroundColor(Color(hex: "7D8B82"))
                            Text("Tap to take selfie").font(.subheadline).foregroundColor(Color(hex: "7D8B82"))
                        }
                    }
                }
            }
            .onChange(of: selectedSelfieItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = decodeImageData(data) {
                        selfieImage = image
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "face.smiling", text: "Face the camera directly, neutral expression")
                tipRow(icon: "light.max", text: "Even lighting on your face")
                tipRow(icon: "eye", text: "Remove sunglasses or masks")
            }
            .padding(14).background(Color(hex: "F8F9FA")).clipShape(RoundedRectangle(cornerRadius: 12))

            Button { submitVerification() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "Submitting..." : "Submit for Verification").font(.headline)
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "5F7A66"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selfieImage == nil || isSubmitting)
            .opacity(selfieImage == nil ? 0.6 : 1)
        }
    }

    // MARK: - Step 3: Reviewing

    private var reviewingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "5F7A66"))
                .padding(.top, 8)

            Text("Reviewing your documents...")
                .font(.title3.bold()).foregroundColor(Color(hex: "1F1F1F"))
            Text("Our system is comparing your student ID with your selfie. This usually takes a few seconds.")
                .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Step 4: Result

    private var resultContent: some View {
        VStack(spacing: 20) {
            if resultStatus == "auto_approved" {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "5F7A66"))
                Text("Verified!").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

                if !detectedUniversity.isEmpty {
                    Text(detectedUniversity).font(.subheadline.bold()).foregroundColor(Color(hex: "5F7A66"))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "5F7A66").opacity(0.1)).clipShape(Capsule())
                }

                Text("Your student status has been verified. You now have a \"Verified by document\" badge.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                Button { dismiss() } label: {
                    Text("Continue").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "5F7A66"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else if resultStatus == "pending_review" {
                Image(systemName: "clock.fill").font(.system(size: 64)).foregroundColor(Color(hex: "FFB347"))
                Text("Under Review").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

                Text("We couldn't auto-verify your documents. A human reviewer will check them within 24 hours. You'll be notified once approved.")
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                Button { dismiss() } label: {
                    Text("Got it").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "FFB347"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Image(systemName: "xmark.circle.fill").font(.system(size: 64)).foregroundColor(Color(hex: "FF6B6B"))
                Text("Verification Failed").font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))

                Text(alertMessage.isEmpty ? "We couldn't verify your documents. Please try again with clearer photos." : alertMessage)
                    .font(.subheadline).foregroundColor(Color(hex: "666666")).multilineTextAlignment(.center)

                Button {
                    step = .idCapture; idImage = nil; selfieImage = nil
                    selectedIdItem = nil; selectedSelfieItem = nil
                } label: {
                    Text("Try Again").font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "5F7A66"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Helpers

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(Color(hex: "5F7A66")).frame(width: 20)
            Text(text).font(.caption).foregroundColor(Color(hex: "555555"))
        }
    }

    // MARK: - API

    private func submitVerification() {
        guard let idImg = idImage, let selfieImg = selfieImage else { return }
        isSubmitting = true
        withAnimation { step = .reviewing }

        Task {
            do {
                guard let idData = imageToJPEGData(idImg, compressionQuality: 0.8),
                      let selfieData = imageToJPEGData(selfieImg, compressionQuality: 0.8) else {
                    alertMessage = "Could not process images."
                    resultStatus = "rejected"; withAnimation { step = .result }
                    isSubmitting = false; return
                }

                // Upload student ID first
                let idResult: StudentIDVerificationResponse = try await APIService.shared.multipartUpload(
                    path: "/student/verify-id",
                    fileData: idData,
                    fileName: "student-id.jpg",
                    mimeType: "image/jpeg",
                    fileField: "student_id")

                // Upload selfie for face match
                let selfieResult: StudentIDVerificationResponse = try await APIService.shared.multipartUpload(
                    path: "/student/verify-id-selfie",
                    fileData: selfieData,
                    fileName: "selfie.jpg",
                    mimeType: "image/jpeg",
                    fileField: "selfie",
                    fields: [
                        "university_name": idResult.universityName ?? "",
                        "name_on_id": idResult.nameOnId ?? ""
                    ])

                detectedUniversity = selfieResult.universityName ?? idResult.universityName ?? ""
                detectedName = selfieResult.nameOnId ?? idResult.nameOnId ?? ""
                resultStatus = selfieResult.status ?? "pending_review"

                if resultStatus == "auto_approved" {
                    await auth.refreshProfile()
                }

                withAnimation { step = .result }
            } catch {
                alertMessage = "Verification failed: \(error.localizedDescription)"
                resultStatus = "rejected"
                withAnimation { step = .result }
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        StudentIDVerificationView()
            .environmentObject(AuthManager())
    }
}
