import SwiftUI
import MapKit
import NavCore
import NavServices

public struct OutdoorView: View {
    @EnvironmentObject var outdoorService: OutdoorService
    @EnvironmentObject var locationManager: LocationManager

    @State private var showAddSpot = false
    @State private var showMap = false
    @State private var selectedCategory: SpotCategory?

    public init() {}

    public var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weatherHeader
                    categoryFilter
                    if outdoorService.isGoldenHour {
                        goldenHourBanner
                    }
                    if let guide = outdoorService.seasonalGuide {
                        seasonalGuideCard(guide)
                    }
                    spotsSection
                }
                .padding(20)
            }
            .refreshable {
                await loadData()
            }
            .overlay {
                if outdoorService.isLoadingSpots && outdoorService.spots.isEmpty {
                    ProgressView()
                        .tint(AppColors.purpleAccent)
                        .scaleEffect(1.2)
                }
            }
        }
        .navigationTitle("Outdoor")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        showMap = true
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Button {
                        showAddSpot = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSpot) {
            AddSpotView()
        }
        .sheet(isPresented: $showMap) {
            OutdoorMapSheet(spots: filteredSpots)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let location = locationManager.location else { return }
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        async let spotsTask: () = outdoorService.fetchSpots(latitude: lat, longitude: lng)
        async let guideTask: () = outdoorService.fetchSeasonalGuide(city: locationManager.city)

        await spotsTask
        await guideTask
    }

    private var filteredSpots: [OutdoorSpot] {
        guard let cat = selectedCategory else { return outdoorService.spots }
        return outdoorService.spots.filter { $0.category == cat }
    }

    // MARK: - Weather Header

    private var weatherHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if let temp = outdoorService.currentTemp {
                    Text("\(Int(temp))°C")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                if let condition = outdoorService.currentCondition {
                    Text(condition.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(locationManager.city)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(outdoorService.currentSeason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "4ECDC4"))

                HStack(spacing: 8) {
                    if let sunrise = outdoorService.sunriseTime {
                        Label(formatTime(sunrise), systemImage: "sunrise.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let sunset = outdoorService.sunsetTime {
                        Label(formatTime(sunset), systemImage: "sunset.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(label: "All", icon: "sparkles", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(SpotCategory.allCases) { cat in
                    filterChip(label: cat.displayName, icon: cat.icon, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
        }
    }

    private func filterChip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "4ECDC4").opacity(0.3) : Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color(hex: "4ECDC4").opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Golden Hour Banner

    private var goldenHourBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.haze.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "F7DC6F"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Golden Hour Now!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Perfect time for sunset viewpoints and photography")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "F7DC6F").opacity(0.15), Color(hex: "FF8E53").opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: "F7DC6F").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Seasonal Guide Card

    private func seasonalGuideCard(_ guide: SeasonalGuideResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: guide.seasonIcon)
                    .foregroundStyle(Color(hex: guide.seasonColor))
                Text("\(guide.season.capitalized) Guide")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            if let tips = guide.tips {
                Text(tips)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(3)
            }

            if let weather = guide.weather {
                HStack(spacing: 16) {
                    if let temp = weather.avgTemp {
                        Label("\(Int(temp))°C avg", systemImage: "thermometer")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let humidity = weather.humidity {
                        Label("\(Int(humidity))%", systemImage: "humidity.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let rain = weather.rainfall {
                        Label("\(Int(rain))mm", systemImage: "cloud.rain")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: guide.seasonColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: guide.seasonColor).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Spots Section

    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Nearby Spots")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(filteredSpots.count) spots")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if filteredSpots.isEmpty && !outdoorService.isLoadingSpots {
                emptyState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredSpots) { spot in
                        NavigationLink {
                            OutdoorSpotDetailView(spot: spot)
                        } label: {
                            SpotCard(spot: spot, isGoldenHour: outdoorService.isGoldenHour)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "4ECDC4").opacity(0.4))

            Text("No spots found nearby")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Be the first to add an outdoor spot!")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))

            Button {
                showAddSpot = true
            } label: {
                Text("Add a Spot")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "4ECDC4"))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Spot Card

struct SpotCard: View {
    let spot: OutdoorSpot
    let isGoldenHour: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: spot.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                    .frame(width: 38, height: 38)
                    .background(Color(hex: "4ECDC4").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(spot.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(spot.category.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))

                        if !spot.formattedDistance.isEmpty {
                            Text("·")
                                .foregroundStyle(.white.opacity(0.3))
                            Text(spot.formattedDistance)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Spacer()

                if let matchLabel = spot.matchLabel {
                    Text(matchLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "4ECDC4"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "4ECDC4").opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Tags row
            HStack(spacing: 8) {
                if let timeLabel = spot.timeLabel {
                    let isTimeNow = isGoldenHour && spot.bestTimeOfDay == "sunset"
                    HStack(spacing: 4) {
                        Image(systemName: isTimeNow ? "sun.haze.fill" : "clock")
                            .font(.system(size: 10))
                        Text(isTimeNow ? "Golden hour now!" : timeLabel)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isTimeNow ? Color(hex: "F7DC6F") : .white.opacity(0.5))
                }

                if let rating = spot.rating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "F7DC6F"))
                }

                if let visits = spot.visitCount, visits > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10))
                        Text("\(visits) visits")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }

            if let desc = spot.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Map Sheet

/// Wrapper that lets us put both OutdoorSpot and TrendingPlace pins on the same map.
private struct MapPin: Identifiable {
    enum Kind { case spot(OutdoorSpot); case trending(TrendingPlace) }
    let id: String
    let coordinate: CLLocationCoordinate2D
    let name: String
    let icon: String
    let kind: Kind
}

struct OutdoorMapSheet: View {
    let spots: [OutdoorSpot]
    @EnvironmentObject var mapSearchService: MapSearchService
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @State private var showTrending = true

    private var allPins: [MapPin] {
        var pins = spots.map { spot in
            MapPin(
                id: "spot_\(spot.id)",
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                name: spot.name,
                icon: spot.category.icon,
                kind: .spot(spot)
            )
        }
        if showTrending {
            let trendingPins = mapSearchService.trendingPlaces.map { place in
                MapPin(
                    id: "trending_\(place.id)",
                    coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    name: place.name,
                    icon: place.iconName,
                    kind: .trending(place)
                )
            }
            pins.append(contentsOf: trendingPins)
        }
        return pins
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: allPins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    mapPinView(pin)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .topLeading) {
                if !mapSearchService.trendingPlaces.isEmpty {
                    Button {
                        showTrending.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text(showTrending ? "Hide Popular" : "Popular Near You")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(showTrending ? .white : .white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(showTrending ? Color(hex: "FF5864").opacity(0.9) : Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                    .padding(.leading, 12)
                }
            }
            .navigationTitle("Outdoor Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.purpleAccent)
                }
            }
            .task {
                if let loc = locationManager.location {
                    region.center = loc.coordinate
                    await mapSearchService.fetchTrending(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                } else if let first = spots.first {
                    region.center = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
                }
            }
        }
    }

    @ViewBuilder
    private func mapPinView(_ pin: MapPin) -> some View {
        switch pin.kind {
        case .spot:
            VStack(spacing: 2) {
                Image(systemName: pin.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "4ECDC4"))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

                Text(pin.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

        case .trending(let place):
            VStack(spacing: 2) {
                ZStack {
                    Image(systemName: pin.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "FF5864"))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

                    // Trending flame badge
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "FF5864"))
                        .offset(x: 12, y: -12)
                }

                Text(pin.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color(hex: "FF5864").opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if place.searchCount > 0 {
                    Text("\(place.searchCount) searches")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
