import SwiftUI
import NavCore
import NavServices

struct ExplorerProfileView: View {
    @EnvironmentObject var mapSearchService: MapSearchService

    private let explorerOrange = Color(hex: "FF8E53")
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if isLoading && mapSearchService.explorerInterests == nil {
                ProgressView()
                    .tint(explorerOrange)
                    .scaleEffect(1.2)
            } else if let interests = mapSearchService.explorerInterests {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        explorerHeader(interests)
                        statsRow(interests)
                        if !interests.topCategories.isEmpty {
                            categoriesSection(interests.topCategories)
                        }
                        if let places = interests.topPlaces, !places.isEmpty {
                            topPlacesSection(places)
                        }
                    }
                    .padding(20)
                }
            } else {
                emptyState
            }
        }
        .navigationTitle("Explorer Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await mapSearchService.fetchExplorerInterests()
            isLoading = false
        }
    }

    // MARK: - Header

    private func explorerHeader(_ interests: ExplorerInterestsResponse) -> some View {
        VStack(spacing: 14) {
            Text(interests.explorerEmoji)
                .font(.system(size: 56))

            Text(interests.explorerType)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Your unique adventure style")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [explorerOrange.opacity(0.15), explorerOrange.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats

    private func statsRow(_ interests: ExplorerInterestsResponse) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(interests.totalSearches)", label: "Searches", icon: "magnifyingglass")

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1, height: 40)

            statItem(value: "\(interests.totalNavigations)", label: "Navigations", icon: "location.fill")

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1, height: 40)

            statItem(value: "\(interests.topCategories.count)", label: "Categories", icon: "square.grid.2x2")
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(explorerOrange)
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Categories

    private func categoriesSection(_ categories: [ExplorerCategory]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(explorerOrange)
                Text("Top Interests")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            ForEach(categories.prefix(8)) { category in
                categoryRow(category, maxCount: categories.first?.count ?? 1)
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func categoryRow(_ category: ExplorerCategory, maxCount: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(category.name.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(category.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(explorerOrange)

                    if let pct = category.percentage {
                        Text("(\(Int(pct))%)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(explorerOrange.opacity(0.12))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(explorerOrange)
                        .frame(
                            width: geo.size.width * CGFloat(maxCount > 0 ? Double(category.count) / Double(maxCount) : 0),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Top Places

    private func topPlacesSection(_ places: [ExplorerTopPlace]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(explorerOrange)
                Text("Top Places")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            ForEach(Array(places.prefix(10).enumerated()), id: \.element.id) { index, place in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(index < 3 ? explorerOrange : .white.opacity(0.4))
                        .frame(width: 22)

                    Text(place.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(place.visitCount) visits")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 4)

                if index < places.prefix(10).count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 34)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(explorerOrange.opacity(0.5))

            Text("No Explorer Data Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Explore spots and get directions to discover your adventure style.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
