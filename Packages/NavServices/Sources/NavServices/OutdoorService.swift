import Foundation
import WeatherKit
import CoreLocation
import NavCore
import NavNetworking

@MainActor
public class OutdoorService: ObservableObject {

    // MARK: - Published State

    @Published public var spots: [OutdoorSpot] = []
    @Published public var seasonalGuide: SeasonalGuideResponse?
    @Published public var memories: [OutdoorVisit] = []
    @Published public var isLoadingSpots = false
    @Published public var isLoadingGuide = false
    @Published public var isLoggingVisit = false

    // MARK: - Weather

    @Published public var currentTemp: Double?
    @Published public var currentCondition: String?
    @Published public var sunriseTime: Date?
    @Published public var sunsetTime: Date?

    private let weatherService = WeatherService.shared

    // MARK: - Init

    public init() {
        if let cached = LocalCache.shared.load(OutdoorSpotsResponse.self, forKey: .outdoorSpots) {
            spots = cached.spots ?? []
        }
        if let cached = LocalCache.shared.load(SeasonalGuideResponse.self, forKey: .seasonalGuide) {
            seasonalGuide = cached
        }
    }

    // MARK: - Fetch Spots (GET /outdoor/spots)

    public func fetchSpots(latitude: Double, longitude: Double) async {
        guard !isLoadingSpots else { return }
        isLoadingSpots = true
        defer { isLoadingSpots = false }

        // Fetch weather in parallel with spots
        async let weatherTask: () = fetchWeather(latitude: latitude, longitude: longitude)

        do {
            var path = "/outdoor/spots?lat=\(latitude)&lng=\(longitude)"
            if let temp = currentTemp { path += "&temp=\(Int(temp))" }
            if let cond = currentCondition { path += "&condition=\(cond.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cond)" }

            let response: OutdoorSpotsResponse = try await APIService.shared.get(path: path)
            spots = response.spots ?? []
            LocalCache.shared.save(response, forKey: .outdoorSpots)
        } catch {
            NavLog.warning("Fetch outdoor spots failed: \(error.localizedDescription)", category: .network)
            if spots.isEmpty,
               let cached = LocalCache.shared.loadStale(OutdoorSpotsResponse.self, forKey: .outdoorSpots) {
                spots = cached.spots ?? []
            }
        }

        await weatherTask
    }

    // MARK: - Create Spot (POST /outdoor/spots)

    public func createSpot(
        name: String,
        description: String,
        category: SpotCategory,
        latitude: Double,
        longitude: Double,
        bestMonths: [Int],
        bestTimeOfDay: String?
    ) async -> OutdoorSpot? {
        var body: [String: Any] = [
            "name": name,
            "description": description,
            "category": category.rawValue,
            "latitude": latitude,
            "longitude": longitude,
            "best_months": bestMonths,
        ]
        if let time = bestTimeOfDay {
            body["best_time_of_day"] = time
        }

        do {
            let response: OutdoorSpotCreateResponse = try await APIService.shared.post(
                path: "/outdoor/spots",
                body: body
            )
            if let spot = response.spot {
                spots.insert(spot, at: 0)
            }
            return response.spot
        } catch {
            NavLog.warning("Create outdoor spot failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Log Visit (POST /outdoor/visit)

    public func logVisit(
        spotId: String,
        weatherTemp: Double?,
        weatherCondition: String?,
        caloriesBurned: Double?,
        durationMinutes: Double?,
        note: String?
    ) async -> OutdoorVisit? {
        guard !isLoggingVisit else { return nil }
        isLoggingVisit = true
        defer { isLoggingVisit = false }

        var body: [String: Any] = ["spot_id": spotId]
        if let temp = weatherTemp { body["weather_temp"] = temp }
        if let cond = weatherCondition { body["weather_condition"] = cond }
        if let cal = caloriesBurned { body["calories_burned"] = cal }
        if let dur = durationMinutes { body["duration_minutes"] = dur }
        if let n = note { body["note"] = n }

        do {
            let response: OutdoorVisitResponse = try await APIService.shared.post(
                path: "/outdoor/visit",
                body: body
            )
            return response.visit
        } catch {
            NavLog.warning("Log outdoor visit failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Fetch Memories (GET /outdoor/memories)

    public func fetchMemories(latitude: Double, longitude: Double) async {
        do {
            let response: OutdoorMemoriesResponse = try await APIService.shared.get(
                path: "/outdoor/memories?lat=\(latitude)&lng=\(longitude)"
            )
            memories = response.visits ?? []
            LocalCache.shared.save(response, forKey: .outdoorMemories)
        } catch {
            NavLog.warning("Fetch outdoor memories failed: \(error.localizedDescription)", category: .network)
            if memories.isEmpty,
               let cached = LocalCache.shared.loadStale(OutdoorMemoriesResponse.self, forKey: .outdoorMemories) {
                memories = cached.visits ?? []
            }
        }
    }

    // MARK: - Seasonal Guide (GET /outdoor/seasonal-guide)

    public func fetchSeasonalGuide(city: String) async {
        guard !isLoadingGuide else { return }
        isLoadingGuide = true
        defer { isLoadingGuide = false }

        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city

        do {
            let response: SeasonalGuideResponse = try await APIService.shared.get(
                path: "/outdoor/seasonal-guide?city=\(encodedCity)"
            )
            seasonalGuide = response
            LocalCache.shared.save(response, forKey: .seasonalGuide)
        } catch {
            NavLog.warning("Fetch seasonal guide failed: \(error.localizedDescription)", category: .network)
            if seasonalGuide == nil,
               let cached = LocalCache.shared.loadStale(SeasonalGuideResponse.self, forKey: .seasonalGuide) {
                seasonalGuide = cached
            }
        }
    }

    // MARK: - WeatherKit

    public func fetchWeather(latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            let weather = try await weatherService.weather(for: location)
            currentTemp = weather.currentWeather.temperature.value
            currentCondition = weather.currentWeather.condition.description

            if let todayForecast = weather.dailyForecast.first {
                sunriseTime = todayForecast.sun.sunrise
                sunsetTime = todayForecast.sun.sunset
            }
        } catch {
            NavLog.debug("WeatherKit fetch failed: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Time-of-Day Helpers

    public var currentTimeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())

        // Check golden hour (near sunset)
        if let sunset = sunsetTime {
            let sunsetHour = Calendar.current.component(.hour, from: sunset)
            if abs(hour - sunsetHour) <= 1 { return "golden_hour" }
        }

        switch hour {
        case 5..<7: return "sunrise"
        case 7..<12: return "morning"
        case 12..<16: return "afternoon"
        case 16..<19: return "sunset"
        case 19..<22: return "evening"
        default: return "night"
        }
    }

    public var isGoldenHour: Bool {
        currentTimeOfDay == "golden_hour" || currentTimeOfDay == "sunset"
    }

    public var currentSeason: String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return "Spring"
        case 6...8: return "Summer"
        case 9...11: return "Autumn"
        default: return "Winter"
        }
    }
}
