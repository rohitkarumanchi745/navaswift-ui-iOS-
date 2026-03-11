import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct ChatView: View {
    @EnvironmentObject var auth: AuthManager
    let match: MatchProfile

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var hasMoreMessages = true
    @State private var isLoadingMore = false
    @EnvironmentObject var callManager: CallManager
    @State private var showCallView = false
    @State private var showProfileDetail = false
    @StateObject private var ws = ChatWebSocket()
    @FocusState private var isInputFocused: Bool
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

                Button { showProfileDetail = true } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: AppConfig.resolvePhotoURL(match.photo)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(AppColors.darkCard)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(match.isOnline ? "Online" : "Last seen recently")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.darkTextSecondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        startCall(type: .video)
                    } label: {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    Button {
                        startCall(type: .audio)
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(AppColors.chatHeader)

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
                        .foregroundStyle(AppColors.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(AppColors.darkBg)
            } else {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        if isLoading {
                            ProgressView()
                                .tint(AppColors.purpleAccent)
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
                                    .foregroundStyle(AppColors.darkTextSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 80)
                        } else {
                            LazyVStack(spacing: 2) {
                                if hasMoreMessages {
                                    Button {
                                        loadOlderMessages()
                                    } label: {
                                        if isLoadingMore {
                                            ProgressView()
                                                .tint(AppColors.purpleAccent)
                                                .padding(8)
                                        } else {
                                            Text("Load earlier messages")
                                                .font(.caption)
                                                .foregroundColor(AppColors.darkTextSecondary)
                                                .padding(8)
                                        }
                                    }
                                }

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
                .scrollDismissesKeyboard(.interactively)
                .background(AppColors.darkBg)

                // Input
                HStack(spacing: 8) {
                    HStack {
                        TextField("Message", text: $draft, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .lineLimit(4)
                            .focused($isInputFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.chatHeader)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: draft.trimmingCharacters(in: .whitespaces).isEmpty ? "mic.fill" : "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(AppColors.chatSendButton)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(AppColors.darkBg)
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadMessages()
            if let token = auth.token {
                ws.connect(matchId: match.matchId, token: token)
            }
        }
        .onDisappear { ws.disconnect() }
        .onChange(of: ws.incomingMessages.count) { _, _ in
            guard let event = ws.incomingMessages.last,
                  event.type == "message",
                  let senderId = event.senderId,
                  senderId != meId else { return }
            let msg = ChatMessage(
                id: "\(event.messageId ?? Int.random(in: 100000...999999))",
                matchId: match.matchId,
                senderId: senderId,
                receiverId: meId ?? 0,
                content: event.content ?? "",
                createdAt: parseISO(event.timestamp),
                status: .delivered
            )
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            CallView()
                .environmentObject(callManager)
        }
        .fullScreenCover(isPresented: $showProfileDetail) {
            MatchProfileDetailView(
                userId: match.id,
                matchName: match.name,
                matchPhoto: match.photo
            )
        }
        .onChange(of: callManager.callState) { _, newState in
            if case .idle = newState {
                showCallView = false
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }

    private func loadMessages(offset: Int = 0) async {
        if offset == 0 { isLoading = true } else { isLoadingMore = true }
        do {
            let query = """
            query Conversation($matchId: String!, $limit: Int, $offset: Int) {
                conversation(matchId: $matchId, limit: $limit, offset: $offset) {
                    id matchId senderId receiverId content createdAt
                }
            }
            """
            let result: [String: Any] = try await APIService.shared.graphQL(
                query: query,
                variables: ["matchId": match.matchId, "limit": 50, "offset": offset]
            )
            if let msgs = result["conversation"] as? [[String: Any]] {
                let parsed = msgs.map { m in
                    ChatMessage(
                        id: "\(m["id"] ?? UUID().uuidString)",
                        matchId: "\(m["matchId"] ?? "")",
                        senderId: (m["senderId"] as? Int) ?? 0,
                        receiverId: (m["receiverId"] as? Int) ?? 0,
                        content: m["content"] as? String ?? "",
                        createdAt: parseISO(m["createdAt"] as? String),
                        status: .delivered
                    )
                }
                if offset == 0 {
                    messages = parsed
                } else {
                    messages.insert(contentsOf: parsed, at: 0)
                }
                hasMoreMessages = parsed.count >= 50
            }
        } catch {
            // Fall back to demo messages if API fails and no messages loaded
            if offset == 0 && messages.isEmpty {
                let partnerId = Int(match.id) ?? 999
                let myId = meId ?? 1
                messages = ChatMessage.demoConversation(
                    matchId: match.matchId,
                    meId: myId,
                    partnerId: partnerId,
                    partnerName: match.name
                )
                hasMoreMessages = false
            }
        }
        isLoading = false
        isLoadingMore = false
    }

    private func loadOlderMessages() {
        guard hasMoreMessages, !isLoadingMore else { return }
        Task { await loadMessages(offset: messages.count) }
    }

    private func sendMessage() {
        let content = draft.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty, let meId else { return }

        let tempId = UUID().uuidString
        let msg = ChatMessage(
            id: tempId,
            matchId: match.matchId,
            senderId: meId,
            receiverId: 0,
            content: content,
            createdAt: Date(),
            status: .sending
        )
        messages.append(msg)
        draft = ""
        isInputFocused = false

        // Send via WebSocket for real-time delivery
        if ws.isConnected {
            ws.sendMessage(content)
        }

        // Persist via GraphQL (server stores the message in DB)
        Task {
            do {
                let mutation = """
                mutation SendChatMessage($matchId: String!, $content: String!) {
                    sendChatMessage(matchId: $matchId, content: $content) {
                        id senderId receiverId content createdAt
                    }
                }
                """
                let result: [String: Any] = try await APIService.shared.graphQL(
                    query: mutation,
                    variables: ["matchId": match.matchId, "content": content]
                )
                if let sent = result["sendChatMessage"] as? [String: Any],
                   let idx = messages.firstIndex(where: { $0.id == tempId }) {
                    messages[idx] = ChatMessage(
                        id: "\(sent["id"] ?? tempId)",
                        matchId: match.matchId,
                        senderId: (sent["senderId"] as? Int) ?? meId,
                        receiverId: (sent["receiverId"] as? Int) ?? 0,
                        content: sent["content"] as? String ?? content,
                        createdAt: parseISO(sent["createdAt"] as? String) ?? Date(),
                        status: .sent
                    )
                }
            } catch {
                if let idx = messages.firstIndex(where: { $0.id == tempId }) {
                    messages[idx].status = .sent
                }
            }
        }
    }

    private func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    private func startCall(type: CallManager.CallType) {
        callManager.startCall(
            type: type,
            matchId: match.matchId,
            partnerName: match.name,
            partnerPhoto: match.photo,
            token: auth.token ?? ""
        )
        showCallView = true
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
                    .foregroundStyle(.white)

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
            .background(isMe ? AppColors.chatSentBubble : AppColors.chatReceivedBubble)
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
                .foregroundStyle(AppColors.purpleAccent)
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
