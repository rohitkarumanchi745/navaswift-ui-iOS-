import SwiftUI
import NavCore
import NavServices

struct OutdoorSpotDetailView: View {
    let spot: OutdoorSpot
    @EnvironmentObject var outdoorService: OutdoorService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var mapSearchService: MapSearchService

    @State private var showLogVisit = false
    @State private var memories: [OutdoorVisit] = []
    @State private var isLoadingMemories = false

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    spotHeader
                    actionButtons
                    detailsSection
                    if !memories.isEmpty {
                        memoriesSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showLogVisit) {
            LogVisitSheet(spot: spot)
        }
        .task {
            mapSearchService.trackSearch(
                latitude: spot.latitude,
                longitude: spot.longitude,
                placeName: spot.name,
                category: spot.category.rawValue
            )
            await loadMemories()
        }
    }

    // MARK: - Header

    private var spotHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: spot.category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                    .frame(width: 52, height: 52)
                    .background(Color(hex: "4ECDC4").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.category.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "4ECDC4"))

                    if let locality = spot.locality {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(locality)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                if let matchLabel = spot.matchLabel {
                    VStack(spacing: 2) {
                        Text(matchLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                        Text("match")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            if let desc = spot.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 16) {
                if let rating = spot.rating, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(hex: "F7DC6F"))
                        Text(String(format: "%.1f", rating))
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 13, weight: .medium))
                }

                if let visits = spot.visitCount, visits > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                        Text("\(visits) visits")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                }

                if !spot.formattedDistance.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                        Text(spot.formattedDistance)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showLogVisit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Log Visit")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(hex: "4ECDC4"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                openInMaps()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                    Text("Directions")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let timeLabel = spot.timeLabel {
                    detailTile(icon: "clock.fill", label: "Best Time", value: timeLabel, color: "F7DC6F")
                }

                if let months = spot.bestMonths, !months.isEmpty {
                    let monthNames = months.prefix(3).map { monthAbbreviation($0) }.joined(separator: ", ")
                    detailTile(icon: "calendar", label: "Best Months", value: monthNames, color: "96CEB4")
                }

                if let temp = outdoorService.currentTemp {
                    detailTile(icon: "thermometer", label: "Now", value: "\(Int(temp))°C", color: "FF8A9E")
                }

                if let condition = outdoorService.currentCondition {
                    detailTile(icon: "cloud.sun.fill", label: "Weather", value: condition.capitalized, color: "85C1E9")
                }
            }

            if let creator = spot.creatorName {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 13))
                    Text("Added by \(creator)")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func detailTile(icon: String, label: String, value: String, color: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: color))

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Memories Section

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color(hex: "BB8FCE"))
                Text("Your Memories")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            ForEach(memories) { visit in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "BB8FCE").opacity(0.2))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.visitedAt)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            if let weather = visit.formattedWeather {
                                Text(weather)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            if let duration = visit.formattedDuration {
                                Text(duration)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            if let cal = visit.caloriesBurned, cal > 0 {
                                Text("\(Int(cal)) cal")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "FF8A9E"))
                            }
                        }

                        if let note = visit.note, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Helpers

    private func loadMemories() async {
        isLoadingMemories = true
        defer { isLoadingMemories = false }
        await outdoorService.fetchMemories(latitude: spot.latitude, longitude: spot.longitude)
        memories = outdoorService.memories
    }

    private func openInMaps() {
        mapSearchService.trackSearch(
            latitude: spot.latitude,
            longitude: spot.longitude,
            placeName: spot.name,
            category: spot.category.rawValue,
            navigated: true
        )
        let url = URL(string: "http://maps.apple.com/?daddr=\(spot.latitude),\(spot.longitude)&dirflg=w")!
        UIApplication.shared.open(url)
    }

    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}

// MARK: - Log Visit Sheet

struct LogVisitSheet: View {
    let spot: OutdoorSpot
    @EnvironmentObject var outdoorService: OutdoorService
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var durationMinutes: Double = 60
    @State private var caloriesBurned: Double = 200
    @State private var didLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if didLog {
                    visitLoggedConfirmation
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duration")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))

                                HStack {
                                    Slider(value: $durationMinutes, in: 10...360, step: 10)
                                        .tint(Color(hex: "4ECDC4"))
                                    Text("\(Int(durationMinutes))m")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 50)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Calories Burned")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))

                                HStack {
                                    Slider(value: $caloriesBurned, in: 50...2000, step: 25)
                                        .tint(Color(hex: "FF8A9E"))
                                    Text("\(Int(caloriesBurned))")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 50)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (optional)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))

                                TextField("How was the visit?", text: $note, axis: .vertical)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .lineLimit(3...5)
                            }

                            Button {
                                Task { await logVisit() }
                            } label: {
                                HStack(spacing: 6) {
                                    if outdoorService.isLoggingVisit {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Log Visit")
                                    }
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "4ECDC4"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(outdoorService.isLoggingVisit)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Log Visit — \(spot.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var visitLoggedConfirmation: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "4ECDC4"))

            Text("Visit Logged!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("\(Int(durationMinutes))m · \(Int(caloriesBurned)) cal burned")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))

            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color(hex: "4ECDC4"))
                .clipShape(Capsule())
                .padding(.top, 10)
        }
    }

    private func logVisit() async {
        let result = await outdoorService.logVisit(
            spotId: spot.id,
            weatherTemp: outdoorService.currentTemp,
            weatherCondition: outdoorService.currentCondition,
            caloriesBurned: caloriesBurned,
            durationMinutes: durationMinutes,
            note: note.isEmpty ? nil : note
        )

        if result != nil {
            withAnimation { didLog = true }
        }
    }
}
