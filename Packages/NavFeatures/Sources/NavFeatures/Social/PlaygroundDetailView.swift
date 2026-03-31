import SwiftUI
import NavCore
import NavNetworking

struct PlaygroundDetailView: View {
    let playground: Playground

    @State private var members: [PlaygroundMember] = []
    @State private var isJoined: Bool
    @State private var memberCount: Int
    @State private var isLoading = false

    init(playground: Playground) {
        self.playground = playground
        _isJoined = State(initialValue: playground.isJoined)
        _memberCount = State(initialValue: playground.memberCount)
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 12) {
                        // Type badge
                        HStack(spacing: 6) {
                            Image(systemName: playground.type.icon)
                                .font(.system(size: 13))
                            Text(playground.type.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.purpleAccent.opacity(0.2))
                        .foregroundStyle(AppColors.purpleAccent)
                        .clipShape(Capsule())

                        Text(playground.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        // Creator & meta
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                Text(playground.creatorName ?? "Unknown")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(.white.opacity(0.6))

                            HStack(spacing: 4) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 12))
                                Text("\(memberCount) members")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(.white.opacity(0.6))

                            if let locality = playground.locality {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 12))
                                    Text(locality)
                                        .font(.system(size: 14))
                                }
                                .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }

                    // Description
                    if let desc = playground.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Join / Leave button
                    Button {
                        Task { await toggleJoin() }
                    } label: {
                        Text(isJoined ? "Leave" : "Join")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isJoined ? Color.red.opacity(0.8) : AppColors.purpleAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading)

                    // Members section
                    if !members.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Members")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(members) { member in
                                        VStack(spacing: 6) {
                                            AsyncImage(url: URL(string: member.photo ?? "")) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Circle().fill(AppColors.darkCard)
                                            }
                                            .frame(width: 48, height: 48)
                                            .clipShape(Circle())

                                            Text(member.name)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .lineLimit(1)
                                        }
                                        .frame(width: 60)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(playground.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadMembers() }
    }

    private func loadMembers() async {
        do {
            let response: PlaygroundMembersResponse = try await APIService.shared.get(
                path: "/playgrounds/\(playground.id)/members"
            )
            members = response.members ?? []
        } catch {
            NavLog.warning("Load playground members failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func toggleJoin() async {
        isLoading = true
        defer { isLoading = false }

        let path = isJoined
            ? "/playgrounds/\(playground.id)/leave"
            : "/playgrounds/\(playground.id)/join"

        do {
            let _: PlaygroundActionResponse = try await APIService.shared.post(
                path: path,
                body: [:]
            )
            isJoined.toggle()
            memberCount += isJoined ? 1 : -1
            if isJoined {
                await loadMembers()
            }
        } catch {
            NavLog.warning("Playground join/leave failed: \(error.localizedDescription)", category: .network)
        }
    }
}
