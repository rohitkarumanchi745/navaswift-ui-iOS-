import SwiftUI
import NavCore
import NavNetworking

struct MessageRequestDetailView: View {
    let profile: LikedProfile
    let isPremium: Bool
    var onAccept: ((MatchProfile) -> Void)?
    var onDecline: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    @State private var showReplyField = false
    @State private var actionTaken: ActionType?
    @State private var isProcessing = false
    @State private var acceptedMatch: MatchProfile?
    @State private var navigateToChat = false

    enum ActionType {
        case accepted, replied, declined
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if let action = actionTaken {
                actionConfirmation(action)
            } else {
                mainContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Message Request")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .navigationDestination(isPresented: $navigateToChat) {
            if let match = acceptedMatch {
                ChatView(match: match)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile photo
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: AppConfig.resolvePhotoURL(profile.photo)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Rectangle().fill(AppColors.darkCard)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                        case .empty:
                            Rectangle().fill(AppColors.darkCard)
                                .overlay { ProgressView().tint(AppColors.purpleAccent) }
                        @unknown default:
                            Rectangle().fill(AppColors.darkCard)
                        }
                    }
                    .frame(height: 380)
                    .clipped()

                    // Blur for non-premium
                    if !isPremium {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 380)
                    }

                    // Gradient overlay
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.5),
                            .init(color: AppColors.darkBg, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Name overlay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(isPremium ? profile.name : "Someone")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            if isPremium {
                                Text("\(profile.age)")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        HStack(spacing: 6) {
                            likeTypeBadge
                            Text("\(profile.likedAt) ago")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Message bubble
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text("Their message to you")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let message = profile.message {
                        Text(message)
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.darkCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.purpleAccent.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Reply section
                if showReplyField {
                    replySection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Info card
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("What happens when you respond?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(AppColors.purpleAccent.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(icon: "checkmark.circle.fill", color: AppColors.verified,
                                text: "Accept — reveal your profile and start chatting")
                        infoRow(icon: "bubble.left.fill", color: AppColors.purpleAccent,
                                text: "Reply — respond to their message without sharing your profile yet")
                        infoRow(icon: "xmark.circle.fill", color: Color(hex: "FF6B6B"),
                                text: "Decline — remove this request")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.04))
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer().frame(height: 120)
            }
        }
        .overlay(alignment: .bottom) {
            actionButtons
        }
    }

    // MARK: - Reply Section

    private var replySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your reply")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            ZStack(alignment: .topLeading) {
                if replyText.isEmpty {
                    Text("Write a reply...")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $replyText)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(minHeight: 100, maxHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.purpleAccent.opacity(replyText.isEmpty ? 0.15 : 0.4), lineWidth: 1)
                    )
            )

            HStack {
                Spacer()
                Text("\(replyText.count)/300")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Button {
                sendReply()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                    Text("Send Reply")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? AppColors.purpleAccent.opacity(0.4)
                    : AppColors.purpleAccent
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.darkBg.opacity(0), AppColors.darkBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)

            HStack(spacing: 12) {
                // Decline
                Button { declineRequest() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Decline")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "FF6B6B"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "FF6B6B").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "FF6B6B").opacity(0.25), lineWidth: 1)
                    )
                }

                // Reply
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showReplyField.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Reply")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.purpleAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.purpleAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.purpleAccent.opacity(0.25), lineWidth: 1)
                    )
                }

                // Accept
                Button { acceptRequest() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Accept")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.verified)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(AppColors.darkBg)
        }
        .opacity(showReplyField ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: showReplyField)
    }

    // MARK: - Action Confirmation

    private func actionConfirmation(_ action: ActionType) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(confirmationColor(action).opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: confirmationIcon(action))
                    .font(.system(size: 40))
                    .foregroundStyle(confirmationColor(action))
            }

            Text(confirmationTitle(action))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text(confirmationSubtitle(action))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            if action == .accepted {
                Button {
                    navigateToChat = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 15))
                        Text("Go to Chat")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.verified)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                Button {
                    dismiss()
                } label: {
                    Text("Back to Likes")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 32)
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.purpleAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Helpers

    private var likeTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: profile.type == .superLike ? "star.fill" : "heart.fill")
                .font(.system(size: 10))
            Text(profile.type == .superLike ? "Super Liked you" : "Liked you")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(profile.type == .superLike ? AppColors.superLike : AppColors.purpleAccent)
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func confirmationColor(_ action: ActionType) -> Color {
        switch action {
        case .accepted: return AppColors.verified
        case .replied: return AppColors.purpleAccent
        case .declined: return Color(hex: "FF6B6B")
        }
    }

    private func confirmationIcon(_ action: ActionType) -> String {
        switch action {
        case .accepted: return "checkmark.circle.fill"
        case .replied: return "paperplane.circle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }

    private func confirmationTitle(_ action: ActionType) -> String {
        switch action {
        case .accepted: return "Profile Shared!"
        case .replied: return "Reply Sent!"
        case .declined: return "Request Declined"
        }
    }

    private func confirmationSubtitle(_ action: ActionType) -> String {
        switch action {
        case .accepted:
            return "\(profile.name) can now see your profile. You'll find them in your matches."
        case .replied:
            return "Your reply has been sent to \(profile.name). Your profile stays hidden until you accept."
        case .declined:
            return "This request has been removed. \(profile.name) won't be notified."
        }
    }

    // MARK: - Actions

    private func acceptRequest() {
        isProcessing = true
        Task {
            var matchId = "match-\(profile.id)"

            guard !profile.id.hasPrefix("ls") else {
                await MainActor.run {
                    let match = MatchProfile(
                        id: profile.id, matchId: matchId,
                        name: profile.name, age: profile.age,
                        photo: profile.photo, lastMessage: profile.message,
                        timestamp: "Just now", unreadCount: 0,
                        isOnline: false, isMutual: true,
                        lastSeen: Date()
                    )
                    acceptedMatch = match
                    onAccept?(match)
                    withAnimation(.spring(response: 0.4)) {
                        actionTaken = .accepted
                    }
                    isProcessing = false
                }
                return
            }
            do {
                struct AcceptResponse: Decodable {
                    let success: Bool?
                    let matchId: String?
                    enum CodingKeys: String, CodingKey {
                        case success
                        case matchId = "match_id"
                    }
                }
                let response: AcceptResponse = try await APIService.shared.post(
                    path: "/messages/requests/\(profile.id)/accept",
                    body: [:] as [String: String]
                )
                if let serverMatchId = response.matchId {
                    matchId = serverMatchId
                }
            } catch {
                NavLog.warning("Accept request failed: \(error.localizedDescription)", category: .network)
            }
            await MainActor.run {
                let match = MatchProfile(
                    id: profile.id, matchId: matchId,
                    name: profile.name, age: profile.age,
                    photo: profile.photo, lastMessage: profile.message,
                    timestamp: "Just now", unreadCount: 0,
                    isOnline: false, isMutual: true,
                    lastSeen: Date()
                )
                acceptedMatch = match
                onAccept?(match)
                withAnimation(.spring(response: 0.4)) {
                    actionTaken = .accepted
                }
                isProcessing = false
            }
        }
    }

    private func sendReply() {
        let reply = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return }
        isProcessing = true
        Task {
            guard !profile.id.hasPrefix("ls") else {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        actionTaken = .replied
                    }
                    isProcessing = false
                }
                return
            }
            do {
                struct ReplyResponse: Decodable {
                    let success: Bool?
                    let conversationId: String?
                    enum CodingKeys: String, CodingKey {
                        case success
                        case conversationId = "conversation_id"
                    }
                }
                let _: ReplyResponse = try await APIService.shared.post(
                    path: "/messages/requests/\(profile.id)/reply",
                    body: ["message": reply]
                )
            } catch {
                NavLog.warning("Reply request failed: \(error.localizedDescription)", category: .network)
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.4)) {
                    actionTaken = .replied
                }
                isProcessing = false
            }
        }
    }

    private func declineRequest() {
        isProcessing = true
        Task {
            guard !profile.id.hasPrefix("ls") else {
                await MainActor.run {
                    onDecline?()
                    withAnimation(.spring(response: 0.4)) {
                        actionTaken = .declined
                    }
                    isProcessing = false
                }
                return
            }
            do {
                struct DeclineResponse: Decodable {
                    let success: Bool?
                }
                let _: DeclineResponse = try await APIService.shared.post(
                    path: "/messages/requests/\(profile.id)/decline",
                    body: [:] as [String: String]
                )
            } catch {
                NavLog.warning("Decline request failed: \(error.localizedDescription)", category: .network)
            }
            await MainActor.run {
                onDecline?()
                withAnimation(.spring(response: 0.4)) {
                    actionTaken = .declined
                }
                isProcessing = false
            }
        }
    }
}
