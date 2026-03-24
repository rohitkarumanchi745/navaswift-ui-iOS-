import SwiftUI
import NavCore
import NavNetworking

struct ReelConversationView: View {
    let reelId: String
    let otherUserId: String
    let otherUserName: String
    let otherUserPhoto: String

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ReelThreadMessage] = []
    @State private var matchStatus: ReelMatchStatus = .chatting
    @State private var canRequestMatch = false
    @State private var matchId: String?
    @State private var isLoading = true
    @State private var draft = ""
    @State private var isSending = false
    @State private var showProfileDetail = false
    @State private var showMatchCelebration = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Match status banner
            matchBanner

            // Messages
            messageList

            // Input bar
            inputBar
        }
        .background(AppColors.darkBg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showProfileDetail) {
            NavigationStack {
                MatchProfileDetailView(
                    userId: otherUserId,
                    matchName: otherUserName,
                    matchPhoto: otherUserPhoto
                )
            }
        }
        .fullScreenCover(isPresented: $showMatchCelebration) {
            matchCelebrationOverlay
        }
        .task { await fetchConversation() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            Button { showProfileDetail = true } label: {
                HStack(spacing: 10) {
                    AsyncImage(url: AppConfig.resolvePhotoURL(otherUserPhoto)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.darkCard)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(otherUserName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("via Reel")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.purpleAccent)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.chatHeader)
    }

    // MARK: - Match Status Banner

    @ViewBuilder
    private var matchBanner: some View {
        switch matchStatus {
        case .chatting:
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12))
                Text("Keep chatting to unlock match request")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppColors.darkCard.opacity(0.5))

        case .eligible:
            Button { requestMatch() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                    Text("Request Match")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(AppColors.brandGradient)
            }

        case .requestSent:
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text("Match request sent — waiting for response")
                    .font(.system(size: 12))
            }
            .foregroundStyle(AppColors.purpleAccent)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppColors.darkCard.opacity(0.5))

        case .requestReceived:
            VStack(spacing: 6) {
                Text("\(otherUserName) wants to match!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Button { acceptMatch(accept: true) } label: {
                        Text("Accept")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(AppColors.success)
                            .clipShape(Capsule())
                    }

                    Button { acceptMatch(accept: false) } label: {
                        Text("Decline")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(AppColors.darkCard)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppColors.darkCard.opacity(0.8))

        case .matched:
            EmptyView()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.purpleAccent)
                        .padding(.top, 60)
                } else if messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Start the conversation")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Reply to start chatting with \(otherUserName)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { message in
                            reelBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Bubble

    private func reelBubble(_ message: ReelThreadMessage) -> some View {
        let isMe = message.isMe ?? false
        return HStack {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? AppColors.chatSentBubble : AppColors.chatReceivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(formatTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            HStack {
                TextField("Reply...", text: $draft, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .focused($isInputFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.chatInput)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            Button {
                sendReply()
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(
                    draft.trimmingCharacters(in: .whitespaces).isEmpty
                        ? AppColors.darkCard
                        : AppColors.chatSendButton
                )
                .clipShape(Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(AppColors.darkBg)
    }

    // MARK: - Match Celebration Overlay

    private var matchCelebrationOverlay: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()
                .opacity(0.95)

            VStack(spacing: 24) {
                Spacer()

                // Photos slide together
                HStack(spacing: -20) {
                    AsyncImage(url: AppConfig.resolvePhotoURL(otherUserPhoto)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(AppColors.darkCard)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.purpleAccent, lineWidth: 3))

                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.primary)
                        .zIndex(1)
                }

                Text("It's a Match!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("You and \(otherUserName) liked each other")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button {
                    showMatchCelebration = false
                    // Navigate back — the match is now in ChatView
                    dismiss()
                } label: {
                    Text("Say Hi 👋")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)

                Button {
                    showMatchCelebration = false
                } label: {
                    Text("Keep Browsing")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - API Calls

    private func fetchConversation() async {
        isLoading = true
        do {
            let response: ReelConversationResponse = try await APIService.shared.get(
                path: "/reels/conversation?reel_id=\(reelId)&other_user_id=\(otherUserId)"
            )
            messages = response.messages
            matchStatus = response.matchStatus
            canRequestMatch = response.canRequestMatch
            matchId = response.matchId
        } catch {
            messages = []
        }
        isLoading = false
    }

    private func sendReply() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        isInputFocused = false

        // Optimistic local insert
        let localMsg = ReelThreadMessage(
            id: UUID().uuidString,
            senderId: "me",
            content: text,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            isMe: true
        )
        messages.append(localMsg)
        draft = ""

        Task {
            do {
                let body: [String: Any] = [
                    "reel_id": Int(reelId) ?? 0,
                    "recipient_id": Int(otherUserId) ?? 0,
                    "content": text
                ]
                let _: ReelReplyResponse = try await APIService.shared.post(
                    path: "/reels/reply", body: body
                )
            } catch {
                // Remove optimistic message on failure
                messages.removeAll { $0.id == localMsg.id }
            }
            isSending = false
        }
    }

    private func requestMatch() {
        Task {
            do {
                let body: [String: Any] = [
                    "reel_id": Int(reelId) ?? 0,
                    "target_user_id": Int(otherUserId) ?? 0
                ]
                let response: ReelMatchRequestResponse = try await APIService.shared.post(
                    path: "/reels/match-request", body: body
                )

                if response.isMatch == true {
                    matchStatus = .matched
                    showMatchCelebration = true
                } else {
                    matchStatus = response.status ?? .requestSent
                }
            } catch {
                // Silently fail
            }
        }
    }

    private func acceptMatch(accept: Bool) {
        Task {
            do {
                let body: [String: Any] = [
                    "reel_id": Int(reelId) ?? 0,
                    "requester_id": Int(otherUserId) ?? 0,
                    "accept": accept
                ]
                let response: ReelMatchAcceptResponse = try await APIService.shared.post(
                    path: "/reels/match-accept", body: body
                )

                if accept && response.isMatch == true {
                    matchId = response.matchId
                    matchStatus = .matched
                    showMatchCelebration = true
                } else {
                    matchStatus = response.status ?? .chatting
                }
            } catch {
                // Silently fail
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: dateStr) else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
}
