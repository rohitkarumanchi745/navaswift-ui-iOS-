import SwiftUI
import NavCore
import NavNetworking

struct ReelActivityListView: View {
    let initialActivities: [ReelActivityItem]
    @State private var activities: [ReelActivityItem] = []
    @State private var isLoading = false
    @State private var filterType: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterPill(label: "All", type: nil)
                        filterPill(label: "Likes", type: "like")
                        filterPill(label: "Views", type: "view")
                        filterPill(label: "Messages", type: "message")
                        filterPill(label: "Creator Likes", type: "like_creator")
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppColors.purpleAccent)
                        Text("Loading activity...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if filteredActivities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No activity yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("When people interact with your reels, you'll see it here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredActivities) { item in
                            activityRow(item)

                            AppColors.darkDivider
                                .frame(height: 1)
                                .padding(.leading, 70)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .background(AppColors.darkBg.ignoresSafeArea())
        .navigationTitle("Reel Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.darkBg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { activities = initialActivities }
        .task { await fetchFullActivity() }
    }

    private var filteredActivities: [ReelActivityItem] {
        guard let filterType else { return activities }
        return activities.filter { $0.type == filterType }
    }

    private func filterPill(label: String, type: String?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                filterType = type
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(filterType == type ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(filterType == type ? AppColors.purpleAccent.opacity(0.5) : .white.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    private func activityRow(_ item: ReelActivityItem) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: AppConfig.resolvePhotoURL(item.actorPhoto)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(AppColors.darkCard)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                Image(systemName: item.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: item.iconColor))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.darkBg, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    (Text(item.actorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    +
                    Text(" \(item.activityDescription)")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6)))

                    Spacer()

                    Text(relativeTime(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if let caption = item.reelCaption, !caption.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 9))
                        Text(caption)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func fetchFullActivity() async {
        isLoading = activities.isEmpty
        do {
            let response: ReelActivityResponse = try await APIService.shared.get(
                path: "/reels/activity?limit=50"
            )
            activities = response.activities
            LocalCache.shared.save(response, forKey: .reelActivity)
        } catch {
            if activities.isEmpty {
                if let cached = LocalCache.shared.load(ReelActivityResponse.self, forKey: .reelActivity) {
                    activities = cached.activities
                } else {
                    activities = []
                }
            }
        }
        isLoading = false
    }

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
