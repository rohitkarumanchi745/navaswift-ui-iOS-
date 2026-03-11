import SwiftUI
import NavCore
import NavNetworking

struct ReelInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ReelInboxItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unreadOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Unread filter toggle
                HStack {
                    Text("Reel Messages")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        unreadOnly.toggle()
                        Task { await fetchInbox() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: unreadOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16))
                            Text(unreadOnly ? "Unread" : "All")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(unreadOnly ? AppColors.purpleAccent : .white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppColors.purpleAccent)
                        Text("Loading messages...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await fetchInbox() } }
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColors.purpleAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(unreadOnly ? "No unread messages" : "No reel messages yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("When someone sends you a message on your reel, it will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(messages) { item in
                            NavigationLink {
                                ReelConversationView(
                                    reelId: item.reelId,
                                    otherUserId: item.senderId,
                                    otherUserName: item.senderName,
                                    otherUserPhoto: item.senderPhoto
                                )
                            } label: {
                                inboxRow(item)
                            }
                            .buttonStyle(.plain)

                            AppColors.darkDivider
                                .frame(height: 1)
                                .padding(.leading, 80)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .background(AppColors.darkBg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppColors.purpleAccent)
            }
        }
        .task { await fetchInbox() }
    }

    // MARK: - Inbox Row

    private func inboxRow(_ item: ReelInboxItem) -> some View {
        HStack(spacing: 12) {
            // Sender avatar with unread indicator
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(item.senderPhoto)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(AppColors.darkCard)
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())

                if !item.isRead {
                    Circle()
                        .fill(AppColors.purpleAccent)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(AppColors.darkBg, lineWidth: 2))
                }
            }

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.senderName)
                        .font(.system(size: 15, weight: item.isRead ? .regular : .bold))
                        .foregroundStyle(.white)

                    if let age = item.senderAge {
                        Text("\(age)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Text(relativeTime(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text(item.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(item.isRead ? 0.5 : 0.8))
                    .lineLimit(2)

                if let caption = item.reelCaption, !caption.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 9))
                        Text(caption)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.3))
                }
            }

            // Reel thumbnail
            if item.reelThumbnail != nil {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.darkCard)
                    .frame(width: 36, height: 48)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Fetch

    private func fetchInbox() async {
        isLoading = messages.isEmpty
        errorMessage = nil
        do {
            let path = "/reels/inbox?limit=50&unread_only=\(unreadOnly)"
            let response: ReelInboxResponse = try await APIService.shared.get(path: path)
            messages = response.messages

            // Cache for offline
            LocalCache.shared.save(response, forKey: .reelInbox)
        } catch {
            // Try cached data
            if let cached = LocalCache.shared.load(ReelInboxResponse.self, forKey: .reelInbox) {
                messages = cached.messages
            } else {
                // Fall back to demo data
                messages = ReelInboxItem.demos
            }
        }
        isLoading = false
    }

    // MARK: - Helpers

    private func relativeTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: dateStr) else { return "" }
        let interval = Date().timeIntervalSince(date)

        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }
}
