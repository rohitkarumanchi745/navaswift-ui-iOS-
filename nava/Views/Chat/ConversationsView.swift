import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var conversations = MatchProfile.demos

    private var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Messages")
                        .font(.system(size: 28, weight: .bold))

                    if totalUnread > 0 {
                        Text("\(totalUnread) new")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)

                // Online matches (horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(conversations.filter(\.isOnline)) { match in
                            NavigationLink(destination: ChatView(match: match)) {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .bottomTrailing) {
                                        AsyncImage(url: URL(string: match.photo)) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color(.systemGray5))
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())

                                        Circle()
                                            .fill(AppColors.online)
                                            .frame(width: 14, height: 14)
                                            .overlay {
                                                Circle().strokeBorder(.white, lineWidth: 2)
                                            }
                                    }
                                    Text(match.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Divider().padding(.horizontal, 20)

                // Message list
                VStack(spacing: 0) {
                    ForEach(conversations) { match in
                        NavigationLink(destination: ChatView(match: match)) {
                            HStack(spacing: 12) {
                                ZStack(alignment: .bottomTrailing) {
                                    AsyncImage(url: URL(string: match.photo)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(Color(.systemGray5))
                                    }
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())

                                    if match.isOnline {
                                        Circle()
                                            .fill(AppColors.online)
                                            .frame(width: 14, height: 14)
                                            .overlay {
                                                Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                                            }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(match.name)
                                            .font(.system(size: 15, weight: .bold))
                                        Spacer()
                                        Text(match.timestamp ?? "")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(match.lastMessage ?? "")
                                        .font(.system(size: 14))
                                        .foregroundStyle(match.unreadCount > 0 ? .primary : .secondary)
                                        .fontWeight(match.unreadCount > 0 ? .medium : .regular)
                                        .lineLimit(1)
                                }

                                if match.unreadCount > 0 {
                                    Text("\(match.unreadCount)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 24, minHeight: 24)
                                        .background(AppColors.primary)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 10)
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}
