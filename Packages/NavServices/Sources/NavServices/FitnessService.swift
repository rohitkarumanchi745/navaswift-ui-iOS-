import Foundation
import HealthKit
import NavCore
import NavNetworking

@MainActor
public class FitnessService: ObservableObject {

    // MARK: - Published State

    @Published public var fitnessStats: FitnessStatsResponse?
    @Published public var workouts: [FitnessWorkoutsResponse.FitnessWorkout] = []
    @Published public var leaderboard: [FitnessLeaderboardResponse.LeaderboardEntry] = []
    @Published public var goals: FitnessGoalsResponse?
    @Published public var isSyncing = false
    @Published public var isFetchingStats = false
    @Published public var healthKitAuthorized = false
    @Published public var stravaActivities: [StravaActivity] = []

    // MARK: - Strava Integration

    private var stravaAuth: StravaAuthManager?

    public func setStravaAuth(_ auth: StravaAuthManager) {
        self.stravaAuth = auth
    }

    // MARK: - Throttling

    private let lastSyncKey = "fitness_last_sync"
    private let syncIntervalSeconds: TimeInterval = 86400

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        types.insert(HKWorkoutType.workoutType())
        return types
    }

    // MARK: - Init

    public init() {
        if let cached = LocalCache.shared.load(FitnessStatsResponse.self, forKey: .fitnessStats) {
            fitnessStats = cached
        }
        if let cached = LocalCache.shared.load(FitnessWorkoutsResponse.self, forKey: .fitnessWorkouts) {
            workouts = cached.workouts
        }
        if let cached = LocalCache.shared.load(FitnessLeaderboardResponse.self, forKey: .fitnessLeaderboard) {
            leaderboard = cached.entries
        }
        if let cached = LocalCache.shared.load(FitnessGoalsResponse.self, forKey: .fitnessGoals) {
            goals = cached
        }

        if HKHealthStore.isHealthDataAvailable() {
            healthKitAuthorized = UserDefaults.standard.bool(forKey: "healthkit_auth_granted")
        }
    }

    // MARK: - Availability

    public var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Authorization + Sync

    public func requestAuthorizationAndSync() async {
        guard isHealthKitAvailable else {
            NavLog.debug("HealthKit not available on this device", category: .general)
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit does not reveal read-only authorization status for privacy.
            // After requesting, we attempt to query data — empty results mean denied.
            healthKitAuthorized = true
            UserDefaults.standard.set(true, forKey: "healthkit_auth_granted")
            await syncHealthData()
        } catch {
            NavLog.warning("HealthKit authorization failed: \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Sync If Needed (throttled)

    public func syncIfNeeded() async {
        guard isHealthKitAvailable else { return }
        guard healthKitAuthorized else { return }
        guard shouldSync() else {
            NavLog.debug("Fitness sync skipped — last sync was recent", category: .general)
            return
        }
        await syncHealthData()
    }

    // MARK: - Core Sync Logic

    private func syncHealthData() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]

            var workoutDicts: [[String: Any]] = []

            // Source 1: HealthKit
            let recentWorkouts = try await fetchRecentWorkouts()
            let weeklyCalories = try await fetchWeeklyCalories()
            let weeklyActiveMinutes = try await fetchWeeklyActiveMinutes()

            for workout in recentWorkouts {
                let activityType = Self.mapActivityType(workout.workoutActivityType)
                var dict: [String: Any] = [
                    "activity_type": activityType,
                    "source": "healthkit",
                    "start_date": formatter.string(from: workout.startDate),
                    "end_date": formatter.string(from: workout.endDate),
                    "duration_seconds": workout.duration,
                ]
                if let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    dict["calories_burned"] = cal
                }
                if let dist = workout.totalDistance?.doubleValue(for: .meter()) {
                    dict["distance_meters"] = dist
                }
                if let elevation = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
                    dict["elevation_ascended"] = elevation.doubleValue(for: .meter())
                }
                workoutDicts.append(dict)
            }

            // Source 2: Strava
            if let stravaData = await fetchStravaActivities() {
                stravaActivities = stravaData
                for activity in stravaData {
                    var dict: [String: Any] = [
                        "activity_type": activity.backendActivityType,
                        "source": "strava",
                        "strava_id": activity.id,
                        "start_date": activity.startDate,
                        "duration_seconds": activity.movingTime,
                        "distance_meters": activity.distance,
                    ]
                    if let cal = activity.calories { dict["calories_burned"] = cal }
                    if let elev = activity.totalElevationGain { dict["elevation_ascended"] = elev }
                    if let polyline = activity.map?.summaryPolyline { dict["route_polyline"] = polyline }
                    workoutDicts.append(dict)
                }
            }

            let body: [String: Any] = [
                "workouts": workoutDicts,
                "weekly_calories": weeklyCalories,
                "weekly_active_minutes": weeklyActiveMinutes,
                "synced_at": formatter.string(from: Date()),
            ]

            let _: FitnessSyncResponse = try await APIService.shared.post(
                path: "/fitness/sync",
                body: body
            )

            markSynced()
            NavLog.info("Fitness synced: \(workoutDicts.count) workouts (\(recentWorkouts.count) HK + \(stravaActivities.count) Strava), \(Int(weeklyCalories)) cal", category: .general)

            await fetchMyStats()
            await fetchWorkouts()
            await fetchGoals()
            await fetchLeaderboard()
        } catch {
            NavLog.warning("Fitness sync failed: \(error.localizedDescription)", category: .network)
        }
    }

    /// Force-syncs immediately after the user connects Strava (bypasses 24h throttle).
    public func syncStravaNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let activities = await fetchStravaActivities() else {
            NavLog.debug("No Strava data available for immediate sync", category: .general)
            return
        }

        stravaActivities = activities

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var workoutDicts: [[String: Any]] = []
        for activity in activities {
            var dict: [String: Any] = [
                "activity_type": activity.backendActivityType,
                "source": "strava",
                "strava_id": activity.id,
                "start_date": activity.startDate,
                "duration_seconds": activity.movingTime,
                "distance_meters": activity.distance,
            ]
            if let cal = activity.calories { dict["calories_burned"] = cal }
            if let elev = activity.totalElevationGain { dict["elevation_ascended"] = elev }
            if let polyline = activity.map?.summaryPolyline { dict["route_polyline"] = polyline }
            workoutDicts.append(dict)
        }

        do {
            let _: FitnessSyncResponse = try await APIService.shared.post(
                path: "/fitness/sync",
                body: [
                    "workouts": workoutDicts,
                    "synced_at": formatter.string(from: Date()),
                ]
            )
            markSynced()
            NavLog.info("Strava immediate sync: \(activities.count) activities", category: .general)

            await fetchMyStats()
            await fetchWorkouts()
        } catch {
            NavLog.warning("Strava immediate sync failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Strava API

    private func fetchStravaActivities() async -> [StravaActivity]? {
        guard let stravaAuth, stravaAuth.isConnected else { return nil }
        guard let token = await stravaAuth.getAccessToken() else { return nil }

        do {
            let sevenDaysAgo = Int(Date().addingTimeInterval(-7 * 86400).timeIntervalSince1970)
            var request = URLRequest(url: URL(string: "https://www.strava.com/api/v3/athlete/activities?after=\(sevenDaysAgo)&per_page=30")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                NavLog.warning("Strava activities fetch failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .network)
                return nil
            }

            let decoder = JSONDecoder()
            return try decoder.decode([StravaActivity].self, from: data)
        } catch {
            NavLog.warning("Strava activities fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Fetch detailed activity data including segments and photos.
    public func fetchStravaActivityDetail(activityId: Int) async -> StravaActivityDetail? {
        guard let stravaAuth, stravaAuth.isConnected else { return nil }
        guard let token = await stravaAuth.getAccessToken() else { return nil }

        do {
            var request = URLRequest(url: URL(string: "https://www.strava.com/api/v3/activities/\(activityId)?include_all_efforts=true")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            return try JSONDecoder().decode(StravaActivityDetail.self, from: data)
        } catch {
            NavLog.warning("Strava activity detail fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - HealthKit Queries

    private func fetchRecentWorkouts() async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: now,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWeeklyCalories() async throws -> Double {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    private func fetchWeeklyActiveMinutes() async throws -> Double {
        guard let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: exerciseTimeType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch from Backend

    public func fetchMyStats() async {
        isFetchingStats = true
        defer { isFetchingStats = false }

        do {
            let response: FitnessStatsResponse = try await APIService.shared.get(path: "/fitness/stats")
            fitnessStats = response
            LocalCache.shared.save(response, forKey: .fitnessStats)
        } catch {
            NavLog.warning("Fetch fitness stats failed: \(error.localizedDescription)", category: .network)
            if fitnessStats == nil,
               let cached = LocalCache.shared.loadStale(FitnessStatsResponse.self, forKey: .fitnessStats) {
                fitnessStats = cached
            }
        }
    }

    public func fetchWorkouts() async {
        do {
            let response: FitnessWorkoutsResponse = try await APIService.shared.get(path: "/fitness/workouts")
            workouts = response.workouts
            LocalCache.shared.save(response, forKey: .fitnessWorkouts)
        } catch {
            NavLog.warning("Fetch fitness workouts failed: \(error.localizedDescription)", category: .network)
            if workouts.isEmpty,
               let cached = LocalCache.shared.loadStale(FitnessWorkoutsResponse.self, forKey: .fitnessWorkouts) {
                workouts = cached.workouts
            }
        }
    }

    public func fetchLeaderboard() async {
        do {
            let response: FitnessLeaderboardResponse = try await APIService.shared.get(path: "/fitness/leaderboard")
            leaderboard = response.entries
            LocalCache.shared.save(response, forKey: .fitnessLeaderboard)
        } catch {
            NavLog.warning("Fetch fitness leaderboard failed: \(error.localizedDescription)", category: .network)
            if leaderboard.isEmpty,
               let cached = LocalCache.shared.loadStale(FitnessLeaderboardResponse.self, forKey: .fitnessLeaderboard) {
                leaderboard = cached.entries
            }
        }
    }

    public func fetchGoals() async {
        do {
            let response: FitnessGoalsResponse = try await APIService.shared.get(path: "/fitness/goals")
            goals = response
            LocalCache.shared.save(response, forKey: .fitnessGoals)
        } catch {
            NavLog.warning("Fetch fitness goals failed: \(error.localizedDescription)", category: .network)
            if goals == nil,
               let cached = LocalCache.shared.loadStale(FitnessGoalsResponse.self, forKey: .fitnessGoals) {
                goals = cached
            }
        }
    }

    /// Fetch another user's stats (for discover card badge)
    public func fetchStatsForUser(_ userId: String) async -> FitnessStatsResponse? {
        do {
            let response: FitnessStatsResponse = try await APIService.shared.get(
                path: "/fitness/stats/\(userId)"
            )
            return response
        } catch {
            return nil
        }
    }

    // MARK: - Goals

    public func updateGoals(calories: Double, activeMinutes: Double, workouts: Int) async {
        do {
            let response: FitnessGoalsResponse = try await APIService.shared.post(
                path: "/fitness/goals",
                body: [
                    "weekly_calorie_goal": calories,
                    "weekly_active_minutes_goal": activeMinutes,
                    "weekly_workout_goal": workouts,
                ]
            )
            goals = response
            LocalCache.shared.save(response, forKey: .fitnessGoals)
        } catch {
            NavLog.warning("Update fitness goals failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Activity Type Mapping

    static func mapActivityType(_ hkType: HKWorkoutActivityType) -> String {
        switch hkType {
        case .hiking: return "hiking"
        case .walking: return "walking"
        case .running: return "running"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength_training"
        case .dance, .socialDance: return "dance"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairClimbing: return "stair_climbing"
        case .crossTraining, .highIntensityIntervalTraining: return "hiit"
        default: return "other"
        }
    }

    // MARK: - Throttle Helpers

    private func shouldSync() -> Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastSync) >= syncIntervalSeconds
    }

    private func markSynced() {
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
    }
}
