import SwiftUI
import NavCore
import NavNetworking

struct ReelMessageComposer: View {
    let reel: Reel
    @Binding var isPresented: Bool
    @State private var messageText = ""
    @State private var isSending = false
    @State private var sentSuccessfully = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private let maxCharacters = 300

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            if sentSuccessfully {
                successView
            } else {
                composerContent
            }
        }
        .background(AppColors.darkBg)
        .onAppear { isFocused = true }
    }

    // MARK: - Composer Content

    private var composerContent: some View {
        VStack(spacing: 20) {
            // Reel context
            HStack(spacing: 12) {
                // Reel thumbnail placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.darkCard)
                    .frame(width: 44, height: 60)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        AsyncImage(url: AppConfig.resolvePhotoURL(reel.userPhoto)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())

                        Text(reel.userName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        if reel.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.secondary)
                        }
                    }

                    if !reel.caption.isEmpty {
                        Text(reel.caption)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Divider
            AppColors.darkDivider
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Text input
            VStack(alignment: .trailing, spacing: 6) {
                TextField("Write a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .lineLimit(3...6)
                    .focused($isFocused)
                    .padding(14)
                    .background(AppColors.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    )
                    .onChange(of: messageText) { _, newValue in
                        if newValue.count > maxCharacters {
                            messageText = String(newValue.prefix(maxCharacters))
                        }
                    }

                Text("\(messageText.count)/\(maxCharacters)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.error)
                    .padding(.horizontal, 20)
            }

            // Send button
            Button {
                send()
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(isSending ? "Sending..." : "Send Message")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(AppColors.brandGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.purpleAccent)

            Text("Message sent!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text("to \(reel.userName)")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Send

    private func send() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        errorMessage = nil
        isFocused = false

        Task {
            do {
                let body: [String: Any] = ["reel_id": Int(reel.id) ?? 0, "content": text]
                let _: ReelSendMessageResponse = try await APIService.shared.post(
                    path: "/reels/message", body: body
                )
                withAnimation(.spring(response: 0.4)) {
                    sentSuccessfully = true
                }
                try? await Task.sleep(for: .seconds(1.2))
                isPresented = false
            } catch {
                errorMessage = "Failed to send. Try again."
                isSending = false
            }
        }
    }
}
