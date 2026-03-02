import SwiftUI

struct ChatView: View {
    @EnvironmentObject var auth: AuthManager
    let match: MatchProfile

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private var meId: Int? {
        if let id = auth.user?.id { return Int(id) }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                AsyncImage(url: URL(string: match.photo)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(hex: "2A3942"))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(match.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(match.isOnline ? "Online" : "Last seen recently")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "8696A0"))
                }

                Spacer()

                HStack(spacing: 4) {
                    Button {} label: {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    Button {} label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(hex: "1F2C34"))

            if !match.isMutual {
                // Locked chat
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Chat Locked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("You can start messaging once you both like each other. Keep exploring!")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "8696A0"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(hex: "0B141A"))
            } else {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        if isLoading {
                            ProgressView()
                                .tint(Color(hex: "25D366"))
                                .padding(.top, 40)
                        } else if messages.isEmpty {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(.white.opacity(0.05))
                                    .frame(width: 120, height: 120)
                                    .overlay {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.2))
                                    }
                                Text("No messages yet")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Say hi to \(match.name) to start the conversation!")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "8696A0"))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 80)
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message, isMe: message.senderId == meId)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .background(Color(hex: "0B141A"))

                // Input
                HStack(spacing: 8) {
                    Button {} label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "8696A0"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "1F2C34"))
                            .clipShape(Circle())
                    }

                    HStack {
                        TextField("Message", text: $draft, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "E9EDEF"))
                            .lineLimit(4)
                        Button {} label: {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(Color(hex: "8696A0"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "1F2C34"))
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: draft.trimmingCharacters(in: .whitespaces).isEmpty ? "mic.fill" : "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "00A884"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(hex: "0B141A"))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
    }

    private func sendMessage() {
        let content = draft.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty, let meId else { return }

        let msg = ChatMessage(
            id: UUID().uuidString,
            matchId: match.matchId,
            senderId: meId,
            receiverId: 0,
            content: content,
            createdAt: Date(),
            status: .sending
        )

        messages.append(msg)
        draft = ""

        // Mark as delivered after delay (demo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].status = .delivered
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "E9EDEF"))

                HStack(spacing: 4) {
                    Text(formatTime(message.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))

                    if isMe {
                        statusIcon
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isMe ? Color(hex: "005C4B") : Color(hex: "1D282F"))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !isMe { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        case .delivered:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        case .read:
            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "34B7F1"))
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
