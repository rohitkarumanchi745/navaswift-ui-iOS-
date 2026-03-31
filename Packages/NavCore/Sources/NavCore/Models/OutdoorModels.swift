import Foundation

// MARK: - Outdoor Spot

public struct OutdoorSpot: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let category: SpotCategory
    public let latitude: Double
    public let longitude: Double
    public let locality: String?
    public let rating: Double?
    public let visitCount: Int?
    public let matchScore: Int?
    public let distanceKm: Double?
    public let bestMonths: [Int]?
    public let bestTimeOfDay: String?
    public let imageUrl: String?
    public let creatorId: String?
    public let creatorName: String?
    public let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, latitude, longitude, locality, rating
        case visitCount = "visit_count"
        case matchScore = "match_score"
        case distanceKm = "distance_km"
        case bestMonths = "best_months"
        case bestTimeOfDay = "best_time_of_day"
        case imageUrl = "image_url"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case createdAt = "created_at"
    }

    // MARK: - Display Helpers

    public var formattedDistance: String {
        guard let km = distanceKm else { return "" }
        if km < 1 { return "\(Int(km * 1000)) m" }
        return String(format: "%.1f km", km)
    }

    public var matchLabel: String? {
        guard let score = matchScore, score > 0 else { return nil }
        return "\(score)% match"
    }

    public var timeLabel: String? {
        guard let time = bestTimeOfDay else { return nil }
        switch time {
        case "sunrise": return "Sunrise spot"
        case "morning": return "Best in morning"
        case "afternoon": return "Afternoon recommended"
        case "golden_hour": return "Golden hour"
        case "sunset": return "Sunset viewpoint"
        case "evening": return "Evening recommended"
        case "night": return "Night spot"
        default: return time.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Spot Category

public enum SpotCategory: String, Codable, CaseIterable, Identifiable {
    case trek
    case viewpoint
    case photoSpot = "photo_spot"
    case lake
    case park
    case trail
    case heritage
    case waterfall
    case campsite
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .trek: return "Trek"
        case .viewpoint: return "Viewpoint"
        case .photoSpot: return "Photo Spot"
        case .lake: return "Lake"
        case .park: return "Park"
        case .trail: return "Trail"
        case .heritage: return "Heritage"
        case .waterfall: return "Waterfall"
        case .campsite: return "Campsite"
        case .other: return "Other"
        }
    }

    public var icon: String {
        switch self {
        case .trek: return "figure.hiking"
        case .viewpoint: return "binoculars.fill"
        case .photoSpot: return "camera.fill"
        case .lake: return "water.waves"
        case .park: return "leaf.fill"
        case .trail: return "figure.walk"
        case .heritage: return "building.columns.fill"
        case .waterfall: return "drop.fill"
        case .campsite: return "tent.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}

// MARK: - Spots Response (GET /outdoor/spots)

public struct OutdoorSpotsResponse: Codable {
    public let spots: [OutdoorSpot]?
}

// MARK: - Spot Create Response (POST /outdoor/spots)

public struct OutdoorSpotCreateResponse: Codable {
    public let success: Bool?
    public let spot: OutdoorSpot?
}

// MARK: - Visit

public struct OutdoorVisit: Codable, Identifiable {
    public let id: String
    public let spotId: String
    public let spotName: String?
    public let visitedAt: String
    public let weatherTemp: Double?
    public let weatherCondition: String?
    public let caloriesBurned: Double?
    public let durationMinutes: Double?
    public let note: String?
    public let photoUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case spotName = "spot_name"
        case visitedAt = "visited_at"
        case weatherTemp = "weather_temp"
        case weatherCondition = "weather_condition"
        case caloriesBurned = "calories_burned"
        case durationMinutes = "duration_minutes"
        case note
        case photoUrl = "photo_url"
    }

    public var formattedWeather: String? {
        guard let temp = weatherTemp else { return nil }
        let condition = weatherCondition?.capitalized ?? ""
        return "\(Int(temp))°C \(condition)".trimmingCharacters(in: .whitespaces)
    }

    public var formattedDuration: String? {
        guard let minutes = durationMinutes else { return nil }
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}

// MARK: - Visit Log Response (POST /outdoor/visit)

public struct OutdoorVisitResponse: Codable {
    public let success: Bool?
    public let visit: OutdoorVisit?
}

// MARK: - Memories Response (GET /outdoor/memories)

public struct OutdoorMemoriesResponse: Codable {
    public let visits: [OutdoorVisit]?
    public let spotName: String?
    public let totalVisits: Int?

    private enum CodingKeys: String, CodingKey {
        case visits
        case spotName = "spot_name"
        case totalVisits = "total_visits"
    }
}

// MARK: - Seasonal Guide (GET /outdoor/seasonal-guide)

public struct SeasonalGuideResponse: Codable {
    public let season: String
    public let weather: SeasonalWeather?
    public let recommendedSpots: [OutdoorSpot]?
    public let tips: String?

    private enum CodingKeys: String, CodingKey {
        case season, weather, tips
        case recommendedSpots = "recommended_spots"
    }

    public struct SeasonalWeather: Codable {
        public let avgTemp: Double?
        public let humidity: Double?
        public let rainfall: Double?

        private enum CodingKeys: String, CodingKey {
            case avgTemp = "avg_temp"
            case humidity
            case rainfall
        }
    }

    public var seasonIcon: String {
        switch season.lowercased() {
        case "spring": return "leaf.fill"
        case "summer": return "sun.max.fill"
        case "autumn", "fall": return "leaf.arrow.triangle.circlepath"
        case "winter": return "snowflake"
        case "monsoon": return "cloud.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    public var seasonColor: String {
        switch season.lowercased() {
        case "spring": return "96CEB4"
        case "summer": return "FF8A9E"
        case "autumn", "fall": return "F7DC6F"
        case "winter": return "85C1E9"
        case "monsoon": return "4ECDC4"
        default: return "BB8FCE"
        }
    }
}
