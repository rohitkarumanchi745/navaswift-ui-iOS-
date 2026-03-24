import SwiftUI
import AVFoundation
import NavCore
import NavNetworking
import NavServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SelfieVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var camera = SelfieCameraModel()
    @State private var selfieImage: PlatformImage? = nil
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var flashOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                VStack(spacing: 24) {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "5F7A66"), Color(hex: "4ECDC4")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))

                    VStack(spacing: 8) {
                        Text("Live Selfie Verification")
                            .font(.title2.bold()).foregroundColor(Color(hex: "1F1F1F"))
                        Text("Take a real-time selfie to verify your identity and earn a verified badge on your profile.")
                            .font(.subheadline).foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                    }

                    // Live camera preview or captured photo
                    ZStack {
                        if camera.permissionDenied {
                            // Camera permission not granted
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(hex: "5F7A66").opacity(0.5))
                                Text("Camera Access Required")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1F1F1F"))
                                Text("Please enable camera access in Settings to take a selfie.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999999"))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Open Settings")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "5F7A66"))
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(hex: "F0F0F0"))
                        } else if let image = selfieImage {
                            #if canImport(UIKit)
                            Image(uiImage: image).resizable().scaledToFill()
                            #elseif canImport(AppKit)
                            Image(nsImage: image).resizable().scaledToFill()
                            #endif
                        } else {
                            SelfieCameraPreview(session: camera.session)

                            // Face guide hint
                            VStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 13))
                                    Text("Position your face in the frame")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(.bottom, 12)
                            }
                        }

                        // Shutter flash
                        Color.white
                            .opacity(flashOpacity)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color(hex: "5F7A66").opacity(0.3), lineWidth: 1)
                    )

                    if selfieImage == nil && !camera.permissionDenied {
                        // Capture button
                        Button {
                            takeSelfie()
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .frame(width: 28, height: 28)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                }
                                Text("Take Selfie").font(.headline)
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color(hex: "5F7A66"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!camera.isReady)
                        .opacity(camera.isReady ? 1 : 0.5)
                    } else {
                        // Retake / Verify buttons
                        HStack(spacing: 12) {
                            Button {
                                selfieImage = nil
                                camera.reset()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Retake").font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(Color(hex: "5F7A66"))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color(hex: "5F7A66"), lineWidth: 1.5)
                                )
                            }

                            Button { verifySelfie() } label: {
                                HStack(spacing: 8) {
                                    if isSubmitting { ProgressView().tint(.white) }
                                    Image(systemName: "checkmark.shield.fill")
                                    Text(isSubmitting ? "Verifying..." : "Verify").font(.headline)
                                }
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color(hex: "5F7A66"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isSubmitting)
                        }
                    }

                    Button { dismiss() } label: {
                        Text("Skip for now").font(.subheadline).foregroundColor(Color(hex: "999999"))
                    }
                }
                .padding(24).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Verification").navigationBarTitleDisplayMode(.inline)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if camera.permissionDenied {
                // Re-check permission when returning from Settings
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                if status == .authorized {
                    camera.permissionDenied = false
                    camera.start()
                }
            }
        }
        .onChange(of: camera.capturedPhoto) { _, photo in
            if let photo { selfieImage = photo }
        }
        .alert("Verification", isPresented: $showAlert) {
            Button("OK") { if alertMessage.contains("success") { dismiss() } }
        } message: { Text(alertMessage) }
    }

    private func takeSelfie() {
        // Flash animation
        withAnimation(.easeOut(duration: 0.1)) { flashOpacity = 0.6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.2)) { flashOpacity = 0 }
        }
        camera.capturePhoto()
    }

    private func verifySelfie() {
        guard let image = selfieImage else { return }
        isSubmitting = true
        Task {
            // Check selfie contains a face
            guard imageContainsFace(image) else {
                alertMessage = "No face detected in your selfie. Please take a clearer photo."
                selfieImage = nil
                camera.reset()
                isSubmitting = false; showAlert = true; return
            }

            // Compare selfie against profile photos (skip for demo mode or no photos)
            if let photos = auth.user?.photos, !photos.isEmpty, auth.token != nil {
                let referenceImages = await downloadProfilePhotos(photos)
                if !referenceImages.isEmpty {
                    let result = selfieFaceMatchesAnyReference(
                        selfie: image,
                        references: referenceImages
                    )
                    guard result.matches else {
                        alertMessage = "Your selfie doesn't appear to match your profile photos. Please take a selfie of yourself."
                        selfieImage = nil
                        camera.reset()
                        isSubmitting = false; showAlert = true; return
                    }
                }
            }

            await uploadSelfie(image)
        }
    }

    private func uploadSelfie(_ image: PlatformImage) async {
        do {
            guard let imageData = imageToJPEGData(image, compressionQuality: 0.8) else {
                alertMessage = "Could not process image."
                isSubmitting = false; showAlert = true; return
            }

            struct VerifyResponse: Codable {
                let verified: Bool?; let message: String?; let confidence: Double?
            }
            let result: VerifyResponse = try await APIService.shared.multipartUpload(
                path: "/verify/selfie", fileData: imageData,
                fileName: "selfie.jpg", mimeType: "image/jpeg", fileField: "selfie")
            await auth.refreshProfile()
            if result.verified == true {
                alertMessage = "Verification successful! Your profile now has a verified badge."
            } else {
                alertMessage = result.message ?? "Verification could not be completed. Please try again with a clearer photo."
            }
        } catch {
            alertMessage = "Verification failed: \(error.localizedDescription)"
        }
        isSubmitting = false; showAlert = true
    }

    private func downloadProfilePhotos(_ photoPaths: [String]) async -> [PlatformImage] {
        var images: [PlatformImage] = []
        for path in photoPaths {
            guard let url = AppConfig.resolvePhotoURL(path) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = decodeImageData(data) {
                    images.append(image)
                }
            } catch {
                continue
            }
        }
        return images
    }
}

#Preview {
    NavigationStack {
        SelfieVerificationView()
            .environmentObject(AuthManager())
    }
}
