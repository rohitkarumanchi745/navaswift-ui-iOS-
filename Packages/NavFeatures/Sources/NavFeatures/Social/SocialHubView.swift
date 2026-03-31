import SwiftUI
import CoreLocation
import NavCore
import NavNetworking
import NavServices

struct SocialHubView: View {
    @EnvironmentObject var locationManager: LocationManager

    @State private var spots: [Spot] = []
    @State private var events: [Event] = []
    @State private var playgrounds: [Playground] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var createType: CreateType?

    enum CreateType: Identifiable {
        case spot, event, playground
        var id: Int { hashValue }
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Spots section
                    spotsSection

                    // Events section
                    eventsSection

                    // Playgrounds section
                    playgroundsSection
                }
                .padding(.vertical, 16)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(AppColors.purpleAccent)
                            .clipShape(Circle())
                            .shadow(color: AppColors.purpleAccent.opacity(0.4), radius: 8, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(AppColors.purpleAccent)
                    .scaleEffect(1.2)
            }
        }
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .confirmationDialog("Create", isPresented: $showCreateSheet) {
            Button("New Spot") { createType = .spot }
            Button("New Event") { createType = .event }
            Button("New Playground") { createType = .playground }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $createType) { type in
            switch type {
            case .spot:
                CreateSpotView()
                    .environmentObject(locationManager)
            case .event:
                CreateEventView()
                    .environmentObject(locationManager)
            case .playground:
                CreatePlaygroundView()
                    .environmentObject(locationManager)
            }
        }
    }

    // MARK: - Spots Section

    @ViewBuilder
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Spots", icon: "bubble.left.and.bubble.right.fill")

            if spots.isEmpty && !isLoading {
                emptyLabel("No spots nearby")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Create spot circle
                        Button {
                            createType = .spot
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.darkCard)
                                        .frame(width: 68, height: 68)
                                    Image(systemName: "plus")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppColors.purpleAccent)
                                }
                                Text("New")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }

                        ForEach(spots) { spot in
                            NavigationLink(value: spot) {
                                VStack(spacing: 6) {
                                    AsyncImage(url: URL(string: spot.userPhoto ?? "")) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(AppColors.darkCard)
                                    }
                                    .frame(width: 68, height: 68)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [AppColors.purpleAccent, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2.5
                                            )
                                    )

                                    Text(spot.userName.components(separatedBy: " ").first ?? spot.userName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .frame(width: 76)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationDestination(for: Spot.self) { spot in
            SpotDetailView(spot: spot)
        }
    }

    // MARK: - Events Section

    @ViewBuilder
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Events Near Me", icon: "calendar.badge.clock")

            if events.isEmpty && !isLoading {
                emptyLabel("No events nearby")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                eventCard(event)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
        }
    }

    @ViewBuilder
    private func eventCard(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            if let locality = event.locality {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11))
                    Text(locality)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text(shortDate(event.eventDate))
                    .font(.system(size: 13))
            }
            .foregroundStyle(AppColors.purpleAccent)

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("\(event.rsvpCount ?? 0) going")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .frame(width: 200, height: 140, alignment: .leading)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Playgrounds Section

    @ViewBuilder
    private var playgroundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Playgrounds", icon: "person.3.fill")

            if playgrounds.isEmpty && !isLoading {
                emptyLabel("No playgrounds yet")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(playgrounds) { pg in
                        NavigationLink(value: pg) {
                            playgroundCard(pg)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationDestination(for: Playground.self) { pg in
            PlaygroundDetailView(playground: pg)
        }
    }

    @ViewBuilder
    private func playgroundCard(_ pg: Playground) -> some View {
        HStack(spacing: 14) {
            // Type icon
            Image(systemName: pg.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(AppColors.purpleAccent)
                .frame(width: 44, height: 44)
                .background(AppColors.purpleAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(pg.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Type badge
                    Text(pg.type.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.purpleAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.purpleAccent.opacity(0.15))
                        .clipShape(Capsule())

                    Text("\(pg.memberCount) members")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))

                    if let locality = pg.locality {
                        Text("· \(locality)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Join status
            Text(pg.isJoined ? "Joined" : "Join")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pg.isJoined ? .white.opacity(0.5) : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(pg.isJoined ? AppColors.darkCard : AppColors.purpleAccent)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(AppColors.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.purpleAccent)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 20)
    }

    private func shortDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateString)
        }
        guard let date else { return dateString }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - API

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        let lat = locationManager.location?.coordinate.latitude
        let lon = locationManager.location?.coordinate.longitude

        async let spotsTask: () = loadSpots(latitude: lat, longitude: lon)
        async let eventsTask: () = loadEvents(latitude: lat, longitude: lon)
        async let playgroundsTask: () = loadPlaygrounds()

        _ = await (spotsTask, eventsTask, playgroundsTask)
    }

    private func loadSpots(latitude: Double?, longitude: Double?) async {
        do {
            var path = "/spots/feed"
            if let latitude, let longitude {
                path += "?latitude=\(latitude)&longitude=\(longitude)"
            }
            let response: SpotFeedResponse = try await APIService.shared.get(path: path)
            spots = response.spots ?? []
            LocalCache.shared.save(spots, forKey: .spotsFeed)
        } catch {
            if let cached = LocalCache.shared.loadStale([Spot].self, forKey: .spotsFeed) {
                spots = cached
            }
            NavLog.warning("Load spots failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func loadEvents(latitude: Double?, longitude: Double?) async {
        do {
            var path = "/events"
            if let latitude, let longitude {
                path += "?latitude=\(latitude)&longitude=\(longitude)"
            }
            let response: EventListResponse = try await APIService.shared.get(path: path)
            events = response.events ?? []
            LocalCache.shared.save(events, forKey: .nearbyEvents)
        } catch {
            if let cached = LocalCache.shared.loadStale([Event].self, forKey: .nearbyEvents) {
                events = cached
            }
            NavLog.warning("Load events failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func loadPlaygrounds() async {
        do {
            let response: PlaygroundListResponse = try await APIService.shared.get(path: "/playgrounds")
            playgrounds = response.playgrounds ?? []
            LocalCache.shared.save(playgrounds, forKey: .playgrounds)
        } catch let decodingError as DecodingError {
            // Log detailed decoding error for debugging
            NavLog.warning("Load playgrounds decode error: \(decodingError)", category: .network)
            if let cached = LocalCache.shared.loadStale([Playground].self, forKey: .playgrounds) {
                playgrounds = cached
            }
        } catch {
            if let cached = LocalCache.shared.loadStale([Playground].self, forKey: .playgrounds) {
                playgrounds = cached
            }
            NavLog.warning("Load playgrounds failed: \(error.localizedDescription)", category: .network)
        }
    }
}

// MARK: - Hashable Conformances for NavigationLink

extension Spot: Hashable {
    public static func == (lhs: Spot, rhs: Spot) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Event: Hashable {
    public static func == (lhs: Event, rhs: Event) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Playground: Hashable {
    public static func == (lhs: Playground, rhs: Playground) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
