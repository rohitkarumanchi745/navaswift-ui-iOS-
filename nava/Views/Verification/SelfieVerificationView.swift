import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

struct SelfieVerificationView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var selfieImage: PlatformImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @ViewBuilder
    private var selfieImageView: some View {
        if let image = selfieImage {
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
            #endif
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "5F7A66"), Color(hex: "4ECDC4")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Live Selfie Verification")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("Take a quick selfie to verify your identity and earn a verified badge on your profile.")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Selfie capture area
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "F0E6DB"))
                                .frame(height: 260)
                            
                            if selfieImage != nil {
                                selfieImageView
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(hex: "7D8B82"))
                                    
                                    Text("Tap to take a selfie")
                                        .font(.subheadline)
                                        .foregroundColor(Color(hex: "7D8B82"))
                                }
                            }
                        }
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let image = PlatformImage(data: data) {
                                selfieImage = image
                            }
                        }
                    }
                    
                    // Verify button
                    Button {
                        verifySelfie()
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Image(systemName: "checkmark.shield.fill")
                            Text(isSubmitting ? "Verifying..." : "Verify & Continue")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "5F7A66"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(selfieImage == nil || isSubmitting)
                    .opacity(selfieImage == nil ? 0.6 : 1)
                    
                    // Skip button
                    Button {
                        dismiss()
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
                .padding(24)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Verification", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func verifySelfie() {
        guard selfieImage != nil else { return }
        isSubmitting = true
        
        Task {
            do {
                // In production, this would upload the selfie via gqlUpload
                try await Task.sleep(for: .seconds(2))
                alertMessage = "Verification successful! Your profile now has a verified badge."
            } catch {
                alertMessage = "Verification failed. Please try again."
            }
            isSubmitting = false
            showAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        SelfieVerificationView()
            .environmentObject(AuthManager())
    }
}
