import Foundation

// MARK: - Strava Activity (GET /athlete/activities)

public struct StravaActivity: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let type: String
    public let sportType: String?
    public let startDate: String
    public let startDateLocal: String
    public let distance: Double
    public let movingTime: Int
    public let elapsedTime: Int
    public let totalElevationGain: Double?
    public let averageSpeed: Double?
    public let maxSpeed: Double?
    public let averageHeartrate: Double?
    public let maxHeartrate: Double?
    public let calories: Double?
    public let hasKudos: Bool?
    public let kudosCount: Int?
    public let photoCount: Int?
    public let map: StravaMap?

    private enum CodingKeys: String, CodingKey {
        case id, name, type, distance, map, calories
        case sportType = "sport_type"
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case hasKudos = "has_kudos"
        case kudosCount = "kudos_count"
        case photoCount = "photo_count"
    }

    // MARK: - Display Helpers

    public var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        }
        return "\(Int(distance)) m"
    }

    public var formattedDuration: String {
        let hours = movingTime / 3600
        let minutes = (movingTime % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    public var formattedPace: String? {
        guard distance > 0 else { return nil }
        let paceSecondsPerKm = Double(movingTime) / (distance / 1000)
        let paceMinutes = Int(paceSecondsPerKm) / 60
        let paceSeconds = Int(paceSecondsPerKm) % 60
        return "\(paceMinutes):\(String(format: "%02d", paceSeconds)) /km"
    }

    public var formattedElevation: String? {
        guard let gain = totalElevationGain, gain > 0 else { return nil }
        return "\(Int(gain)) m"
    }

    public var iconName: String {
        switch type.lowercased() {
        case "run": return "figure.run"
        case "ride": return "figure.outdoor.cycle"
        case "swim": return "figure.pool.swim"
        case "hike": return "figure.hiking"
        case "walk": return "figure.walk"
        case "yoga": return "figure.yoga"
        case "workout", "weighttraining": return "dumbbell.fill"
        default: return "figure.mixed.cardio"
        }
    }

    public var displayType: String {
        switch type.lowercased() {
        case "run": return "Run"
        case "ride": return "Ride"
        case "swim": return "Swim"
        case "hike": return "Hike"
        case "walk": return "Walk"
        case "yoga": return "Yoga"
        case "workout": return "Workout"
        case "weighttraining": return "Weights"
        case "virtualride": return "Virtual Ride"
        case "virtualrun": return "Virtual Run"
        default: return type
        }
    }

    /// Activity type mapped to the backend's format for /fitness/sync
    public var backendActivityType: String {
        switch type.lowercased() {
        case "run", "virtualrun": return "running"
        case "ride", "virtualride": return "cycling"
        case "swim": return "swimming"
        case "hike": return "hiking"
        case "walk": return "walking"
        case "yoga": return "yoga"
        case "weighttraining", "workout": return "strength_training"
        default: return "other"
        }
    }

    public var hasRoute: Bool {
        map?.summaryPolyline != nil && !(map?.summaryPolyline?.isEmpty ?? true)
    }
}

// MARK: - Strava Map (polyline data)

public struct StravaMap: Codable, Hashable {
    public let id: String?
    public let summaryPolyline: String?
    public let polyline: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case summaryPolyline = "summary_polyline"
        case polyline
    }
}

// MARK: - Strava Segment Effort

public struct StravaSegmentEffort: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let elapsedTime: Int
    public let movingTime: Int
    public let distance: Double
    public let averageHeartrate: Double?
    public let prRank: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, distance
        case elapsedTime = "elapsed_time"
        case movingTime = "moving_time"
        case averageHeartrate = "average_heartrate"
        case prRank = "pr_rank"
    }

    public var formattedTime: String {
        let minutes = elapsedTime / 60
        let seconds = elapsedTime % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    public var prLabel: String? {
        guard let rank = prRank else { return nil }
        switch rank {
        case 1: return "PR!"
        case 2: return "2nd best"
        case 3: return "3rd best"
        default: return nil
        }
    }
}

// MARK: - Strava Activity Detail (GET /activities/:id)

public struct StravaActivityDetail: Codable {
    public let id: Int
    public let name: String
    public let description: String?
    public let type: String
    public let distance: Double
    public let movingTime: Int
    public let elapsedTime: Int
    public let totalElevationGain: Double?
    public let calories: Double?
    public let averageSpeed: Double?
    public let maxSpeed: Double?
    public let averageHeartrate: Double?
    public let maxHeartrate: Double?
    public let map: StravaMap?
    public let segmentEfforts: [StravaSegmentEffort]?
    public let photos: StravaPhotosSummary?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, type, distance, map, calories, photos
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case segmentEfforts = "segment_efforts"
    }
}

// MARK: - Strava Photos

public struct StravaPhotosSummary: Codable {
    public let count: Int?
    public let primary: StravaPhoto?
}

public struct StravaPhoto: Codable {
    public let uniqueId: String?
    public let urls: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case uniqueId = "unique_id"
        case urls
    }

    /// Best available photo URL (prefers 600px, falls back to 100px)
    public var bestURL: URL? {
        if let urlString = urls?["600"] ?? urls?["100"],
           let url = URL(string: urlString) {
            return url
        }
        return nil
    }
}
