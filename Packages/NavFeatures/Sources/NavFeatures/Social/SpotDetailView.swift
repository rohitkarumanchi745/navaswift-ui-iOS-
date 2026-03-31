import SwiftUI
import NavCore
import NavNetworking

struct SpotDetailView: View {
    let spot: Spot

    @State private var messages: [SpotMessage] = []
    @State private var messageText = ""
    @State private var reactCount: Int
    @State private var hasReacted = false
    @State private var isSending = false

    init(spot: Spot) {
        self.spot = spot
        _reactCount = State(initialValue: spot.reactCount ?? 0)
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // User info
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: spot.userPhoto ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(AppColors.darkCard)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(spot.userName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)

                                HStack(spacing: 6) {
                                    if let locality = spot.locality {
                                        Text(locality)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Text("·")
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text(timeAgo(spot.createdAt))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }

                            Spacer()
                        }

                        // Content
                        Text(spot.content)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        // Optional image
                        if let imageUrl = spot.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.darkCard)
                                    .frame(height: 200)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // React button
                        HStack(spacing: 16) {
                            Button {
                                Task { await react() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: hasReacted ? "heart.fill" : "heart")
                                        .foregroundStyle(hasReacted ? .red : .white.opacity(0.6))
                                    Text("\(reactCount)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left")
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("\(messages.count)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()
                        }
                        .padding(.top, 4)

                        Divider().background(.white.opacity(0.1))

                        // Messages
                        if messages.isEmpty {
                            Text("No messages yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { msg in
                                    HStack(alignment: .top, spacing: 10) {
                                        AsyncImage(url: URL(string: msg.senderPhoto ?? "")) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(AppColors.darkCard)
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(msg.senderName)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                Text(timeAgo(msg.createdAt))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }
                                            Text(msg.content)
                                                .font(.system(size: 15))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                // Message input
                HStack(spacing: 12) {
                    TextField("Say something...", text: $messageText)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.darkCard)
                        .clipShape(Capsule())

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .white.opacity(0.2)
                                    : AppColors.purpleAccent
                            )
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.darkBg)
            }
        }
        .navigationTitle("Spot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadMessages() }
    }

    private func loadMessages() async {
        do {
            let response: SpotMessagesResponse = try await APIService.shared.get(
                path: "/spots/\(spot.id)/messages"
            )
            messages = response.messages ?? []
        } catch {
            NavLog.warning("Load spot messages failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        messageText = ""

        do {
            let response: SpotMessagesResponse = try await APIService.shared.post(
                path: "/spots/\(spot.id)/messages",
                body: ["content": text]
            )
            if let newMessages = response.messages {
                messages = newMessages
            } else {
                await loadMessages()
            }
        } catch {
            NavLog.warning("Send spot message failed: \(error.localizedDescription)", category: .network)
        }
        isSending = false
    }

    private func react() async {
        hasReacted.toggle()
        reactCount += hasReacted ? 1 : -1

        do {
            let response: SpotReactResponse = try await APIService.shared.post(
                path: "/spots/\(spot.id)/react",
                body: [:]
            )
            if let count = response.reactCount {
                reactCount = count
            }
        } catch {
            NavLog.warning("Spot react failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func timeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return "" }
            return relativeTime(from: date)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}
