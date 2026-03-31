import Foundation

// MARK: - Fitness Sync (POST /fitness/sync)

public struct FitnessSyncResponse: Codable {
    public let success: Bool?
    public let message: String?
}

// MARK: - Fitness Stats (GET /fitness/stats, GET /fitness/stats/:userId)

public struct FitnessStatsResponse: Codable {
    public let weeklyCalories: Double
    public let weeklyActiveMinutes: Double
    public let weeklyWorkoutCount: Int
    public let currentStreak: Int
    public let fitnessScore: Int
    public let topActivity: String?

    private enum CodingKeys: String, CodingKey {
        case weeklyCalories = "weekly_calories"
        case weeklyActiveMinutes = "weekly_active_minutes"
        case weeklyWorkoutCount = "weekly_workout_count"
        case currentStreak = "current_streak"
        case fitnessScore = "fitness_score"
        case topActivity = "top_activity"
    }
}

// MARK: - Fitness Workouts (GET /fitness/workouts)

public struct FitnessWorkoutsResponse: Codable {
    public let workouts: [FitnessWorkout]

    public struct FitnessWorkout: Codable, Identifiable, Hashable {
        public let id: String
        public let activityType: String
        public let startDate: String
        public let durationSeconds: Double
        public let caloriesBurned: Double?
        public let distanceMeters: Double?
        public let elevationAscended: Double?
        public let locationName: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case activityType = "activity_type"
            case startDate = "start_date"
            case durationSeconds = "duration_seconds"
            case caloriesBurned = "calories_burned"
            case distanceMeters = "distance_meters"
            case elevationAscended = "elevation_ascended"
            case locationName = "location_name"
        }

        // MARK: - Computed Helpers

        public var displayType: String {
            switch activityType {
            case "hiking": return "Hiking"
            case "walking": return "Walking"
            case "running": return "Running"
            case "cycling": return "Cycling"
            case "swimming": return "Swimming"
            case "yoga": return "Yoga"
            case "strength_training": return "Strength"
            case "dance": return "Dance"
            case "elliptical": return "Elliptical"
            case "rowing": return "Rowing"
            case "stair_climbing": return "Stair Climbing"
            case "hiit": return "HIIT"
            default: return activityType.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }

        public var iconName: String {
            switch activityType {
            case "hiking": return "figure.hiking"
            case "walking": return "figure.walk"
            case "running": return "figure.run"
            case "cycling": return "figure.outdoor.cycle"
            case "swimming": return "figure.pool.swim"
            case "yoga": return "figure.yoga"
            case "strength_training": return "dumbbell.fill"
            case "dance": return "figure.dance"
            case "elliptical": return "figure.elliptical"
            case "rowing": return "figure.rowing"
            case "stair_climbing": return "figure.stair.stepper"
            case "hiit": return "figure.highintensity.intervaltraining"
            default: return "figure.mixed.cardio"
            }
        }

        public var isHikingType: Bool {
            activityType == "hiking" || activityType == "walking"
        }

        public var formattedDuration: String {
            let hours = Int(durationSeconds) / 3600
            let minutes = (Int(durationSeconds) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        public var formattedDistance: String? {
            guard let distance = distanceMeters else { return nil }
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000)
            }
            return "\(Int(distance)) m"
        }

        public var formattedElevation: String? {
            guard let elevation = elevationAscended else { return nil }
            return "\(Int(elevation)) m"
        }
    }
}

// MARK: - Fitness Leaderboard (GET /fitness/leaderboard)

public struct FitnessLeaderboardResponse: Codable {
    public let entries: [LeaderboardEntry]

    public struct LeaderboardEntry: Codable, Identifiable {
        public let id: String
        public let name: String
        public let photo: String?
        public let fitnessScore: Int
        public let weeklyWorkoutCount: Int
        public let rank: Int

        private enum CodingKeys: String, CodingKey {
            case id, name, photo, rank
            case fitnessScore = "fitness_score"
            case weeklyWorkoutCount = "weekly_workout_count"
        }
    }
}

// MARK: - Fitness Goals (GET/POST /fitness/goals)

public struct FitnessGoalsResponse: Codable {
    public let weeklyCalorieGoal: Double
    public let weeklyActiveMinutesGoal: Double
    public let weeklyWorkoutGoal: Int
    public let currentCalories: Double
    public let currentActiveMinutes: Double
    public let currentWorkouts: Int

    private enum CodingKeys: String, CodingKey {
        case weeklyCalorieGoal = "weekly_calorie_goal"
        case weeklyActiveMinutesGoal = "weekly_active_minutes_goal"
        case weeklyWorkoutGoal = "weekly_workout_goal"
        case currentCalories = "current_calories"
        case currentActiveMinutes = "current_active_minutes"
        case currentWorkouts = "current_workouts"
    }

    public var calorieProgress: Double {
        guard weeklyCalorieGoal > 0 else { return 0 }
        return min(1.0, currentCalories / weeklyCalorieGoal)
    }

    public var activeMinutesProgress: Double {
        guard weeklyActiveMinutesGoal > 0 else { return 0 }
        return min(1.0, currentActiveMinutes / weeklyActiveMinutesGoal)
    }

    public var workoutProgress: Double {
        guard weeklyWorkoutGoal > 0 else { return 0 }
        return min(1.0, Double(currentWorkouts) / Double(weeklyWorkoutGoal))
    }
}
