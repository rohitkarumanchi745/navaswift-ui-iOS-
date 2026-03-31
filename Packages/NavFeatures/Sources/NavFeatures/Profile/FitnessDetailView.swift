import SwiftUI
import MapKit
import NavCore
import NavNetworking
import NavServices

struct FitnessDetailView: View {
    @EnvironmentObject var fitnessService: FitnessService
    @EnvironmentObject var stravaAuth: StravaAuthManager

    private let fitnessGreen = Color(hex: "34C759")
    private let fitnessCyan = Color(hex: "00BCD4")
    private let fitnessPink = Color(hex: "FF8A9E")
    private let stravaOrange = Color(hex: "FC4C02")

    @State private var showGoalEditor = false
    @State private var editCalorieGoal: Double = 2000
    @State private var editMinutesGoal: Double = 150
    @State private var editWorkoutGoal: Int = 5
    @State private var selectedStravaActivity: StravaActivity?

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if !fitnessService.isHealthKitAvailable {
                unavailableState
            } else if !fitnessService.healthKitAuthorized {
                permissionPrompt
            } else if fitnessService.isSyncing && fitnessService.fitnessStats == nil {
                ProgressView()
                    .tint(AppColors.purpleAccent)
                    .scaleEffect(1.2)
            } else if fitnessService.fitnessStats == nil {
                emptyState
            } else {
                contentView
            }
        }
        .navigationTitle("Fitness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showGoalEditor) {
            goalEditorSheet
        }
        .sheet(item: $selectedStravaActivity) { activity in
            StravaActivityDetailSheet(activity: activity, fitnessService: fitnessService)
        }
        .onChange(of: stravaAuth.isConnected) { _, connected in
            if connected {
                Task { await fitnessService.syncStravaNow() }
            }
        }
        .alert("Strava Error", isPresented: .constant(stravaAuth.authError != nil)) {
            Button("OK") { stravaAuth.authError = nil }
        } message: {
            Text(stravaAuth.authError ?? "")
        }
    }

    // MARK: - Main Content

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stravaConnectionSection
                weeklyStatsSection
                if !fitnessService.stravaActivities.isEmpty {
                    stravaActivitiesSection
                }
                goalsSection
                recentWorkoutsSection
                leaderboardSection
            }
            .padding(20)
        }
    }

    // MARK: - Strava Connection

    private var stravaConnectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if stravaAuth.isConnected {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(stravaOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strava Connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Route maps, segments & photos synced")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        stravaAuth.disconnect()
                    } label: {
                        Text("Disconnect")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(stravaOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(stravaOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(stravaOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(stravaOrange.opacity(0.2), lineWidth: 1)
                )
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 18))
                            .foregroundStyle(stravaOrange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Strava")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Get route maps, segment efforts & activity photos")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()
                    }

                    Button {
                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = scene.windows.first else { return }
                        stravaAuth.startAuth(presentationAnchor: window)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Connect Strava")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [stravaOrange, Color(hex: "E64500")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(stravaAuth.isAuthenticating)
                    .opacity(stravaAuth.isAuthenticating ? 0.6 : 1)
                }
                .padding(14)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Strava Activities

    private var stravaActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14))
                        .foregroundStyle(stravaOrange)
                    Text("Strava Activities")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("\(fitnessService.stravaActivities.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach(fitnessService.stravaActivities) { activity in
                Button {
                    selectedStravaActivity = activity
                } label: {
                    stravaActivityRow(activity)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func stravaActivityRow(_ activity: StravaActivity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: activity.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(stravaOrange)
                    .frame(width: 34, height: 34)
                    .background(stravaOrange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(activity.displayType)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(activity.formattedDuration)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(activity.formattedDistance)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(stravaOrange)

                    if activity.hasRoute {
                        HStack(spacing: 3) {
                            Image(systemName: "map")
                                .font(.system(size: 9))
                            Text("Route")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(stravaOrange.opacity(0.7))
                    }
                }
            }

            // Route map preview
            if activity.hasRoute, let polyline = activity.map?.summaryPolyline {
                PolylineMapPreview(encodedPolyline: polyline, tintColor: stravaOrange)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Stats row
            HStack(spacing: 16) {
                if let pace = activity.formattedPace {
                    detailChip(icon: "speedometer", text: pace)
                }
                if let elevation = activity.formattedElevation {
                    detailChip(icon: "arrow.up.right", text: "\(elevation) elev")
                }
                if let cal = activity.calories {
                    detailChip(icon: "flame", text: "\(Int(cal)) cal")
                }
                if let hr = activity.averageHeartrate {
                    detailChip(icon: "heart", text: "\(Int(hr)) bpm")
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Weekly Stats

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let streak = fitnessService.fitnessStats?.currentStreak, streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(streak) week streak")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            HStack(spacing: 16) {
                statRing(
                    value: fitnessService.fitnessStats?.weeklyCalories ?? 0,
                    unit: "cal",
                    label: "Calories",
                    color: fitnessGreen,
                    progress: fitnessService.goals?.calorieProgress ?? 0
                )

                statRing(
                    value: fitnessService.fitnessStats?.weeklyActiveMinutes ?? 0,
                    unit: "min",
                    label: "Active",
                    color: fitnessCyan,
                    progress: fitnessService.goals?.activeMinutesProgress ?? 0
                )

                statRing(
                    value: Double(fitnessService.fitnessStats?.weeklyWorkoutCount ?? 0),
                    unit: "",
                    label: "Workouts",
                    color: fitnessPink,
                    progress: fitnessService.goals?.workoutProgress ?? 0
                )
            }
            .padding(16)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statRing(value: Double, unit: String, label: String, color: Color, progress: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Goals")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    if let g = fitnessService.goals {
                        editCalorieGoal = g.weeklyCalorieGoal
                        editMinutesGoal = g.weeklyActiveMinutesGoal
                        editWorkoutGoal = g.weeklyWorkoutGoal
                    }
                    showGoalEditor = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(fitnessGreen)
                }
            }

            if let goals = fitnessService.goals {
                goalProgressRow(
                    label: "Calories",
                    current: goals.currentCalories,
                    goal: goals.weeklyCalorieGoal,
                    unit: "cal",
                    color: fitnessGreen
                )
                goalProgressRow(
                    label: "Active Minutes",
                    current: goals.currentActiveMinutes,
                    goal: goals.weeklyActiveMinutesGoal,
                    unit: "min",
                    color: fitnessCyan
                )
                goalProgressRow(
                    label: "Workouts",
                    current: Double(goals.currentWorkouts),
                    goal: Double(goals.weeklyWorkoutGoal),
                    unit: "",
                    color: fitnessPink
                )
            } else {
                Text("Set goals to track your weekly progress")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func goalProgressRow(label: String, current: Double, goal: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(current))/\(Int(goal)) \(unit)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(1.0, goal > 0 ? current / goal : 0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Recent Workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Workouts")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            if fitnessService.workouts.isEmpty {
                Text("No workouts this week")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(fitnessService.workouts) { workout in
                    workoutRow(workout)

                    if workout.id != fitnessService.workouts.last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func workoutRow(_ workout: FitnessWorkoutsResponse.FitnessWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: workout.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(fitnessGreen)
                    .frame(width: 34, height: 34)
                    .background(fitnessGreen.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.displayType)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Text(workout.formattedDuration)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if let cal = workout.caloriesBurned {
                    Text("\(Int(cal)) cal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(fitnessGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(fitnessGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Hiking/trekking specific details
            if workout.isHikingType {
                HStack(spacing: 16) {
                    if let distance = workout.formattedDistance {
                        detailChip(icon: "arrow.left.and.right", text: distance)
                    }
                    if let elevation = workout.formattedElevation {
                        detailChip(icon: "arrow.up.right", text: "\(elevation) elev")
                    }
                    if let location = workout.locationName {
                        detailChip(icon: "mappin", text: location)
                    }
                }
                .padding(.leading, 46)
            }
        }
        .padding(.vertical, 4)
    }

    private func detailChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.45))
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Friends Leaderboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(AppColors.gold)
            }

            if fitnessService.leaderboard.isEmpty {
                Text("Match with fitness-loving people to compete!")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(fitnessService.leaderboard) { entry in
                    leaderboardRow(entry)

                    if entry.id != fitnessService.leaderboard.last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 54)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func leaderboardRow(_ entry: FitnessLeaderboardResponse.LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(entry.rank <= 3 ? AppColors.gold : .white.opacity(0.5))
                .frame(width: 24)

            if let photoPath = entry.photo, let url = AppConfig.resolvePhotoURL(photoPath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                    default:
                        leaderboardPlaceholder
                    }
                }
            } else {
                leaderboardPlaceholder
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(entry.weeklyWorkoutCount) workouts")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text("\(entry.fitnessScore)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(fitnessGreen)
        }
        .padding(.vertical, 4)
    }

    private var leaderboardPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 34))
            .foregroundStyle(.white.opacity(0.2))
            .frame(width: 38, height: 38)
    }

    // MARK: - Permission Prompt

    private var permissionPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 52))
                .foregroundStyle(fitnessGreen.opacity(0.6))

            Text("Track Your Fitness")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Connect HealthKit to show your workouts, compete with matches, and share your fitness journey. Works with Apple Watch, Whoop, Fitbit, and Garmin.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await fitnessService.requestAuthorizationAndSync() }
            } label: {
                Text("Connect HealthKit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "34C759"), Color(hex: "30D158")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Empty / Unavailable States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(fitnessGreen.opacity(0.5))

            Text("No Fitness Data Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Start a workout with your Apple Watch or fitness tracker. Data will sync automatically.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("HealthKit Unavailable")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("HealthKit is not available on this device.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Goal Editor Sheet

    private var goalEditorSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        goalEditorRow(
                            title: "Weekly Calorie Goal",
                            value: $editCalorieGoal,
                            step: 100,
                            range: 500...10000,
                            unit: "cal",
                            color: fitnessGreen
                        )

                        goalEditorRow(
                            title: "Weekly Active Minutes",
                            value: $editMinutesGoal,
                            step: 15,
                            range: 30...600,
                            unit: "min",
                            color: fitnessCyan
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Workout Goal")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            Stepper(value: $editWorkoutGoal, in: 1...14) {
                                HStack {
                                    Text("\(editWorkoutGoal)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(fitnessPink)
                                    Text("workouts")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .tint(fitnessPink)
                            .padding(14)
                            .background(AppColors.darkCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showGoalEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await fitnessService.updateGoals(
                                calories: editCalorieGoal,
                                activeMinutes: editMinutesGoal,
                                workouts: editWorkoutGoal
                            )
                            showGoalEditor = false
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }

    private func goalEditorRow(title: String, value: Binding<Double>, step: Double, range: ClosedRange<Double>, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Button {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(Int(value.wrappedValue))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                }
            }
            .padding(14)
            .background(AppColors.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Polyline Map Preview

struct PolylineMapPreview: View {
    let encodedPolyline: String
    let tintColor: Color

    private var coordinates: [CLLocationCoordinate2D] {
        PolylineDecoder.decode(encodedPolyline)
    }

    var body: some View {
        if coordinates.count >= 2 {
            let region = PolylineDecoder.region(for: coordinates)
            Map(coordinateRegion: .constant(region), annotationItems: []) { (_: EmptyAnnotation) in
                MapMarker(coordinate: CLLocationCoordinate2D())
            }
            .overlay {
                PolylineOverlay(coordinates: coordinates, color: tintColor)
            }
            .disabled(true)
            .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    Text("No route data")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
        }
    }
}

private struct EmptyAnnotation: Identifiable {
    let id = UUID()
}

// MARK: - Polyline Overlay (Canvas-based)

struct PolylineOverlay: View {
    let coordinates: [CLLocationCoordinate2D]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard coordinates.count >= 2 else { return }

                let lats = coordinates.map { $0.latitude }
                let lngs = coordinates.map { $0.longitude }
                let minLat = lats.min()!, maxLat = lats.max()!
                let minLng = lngs.min()!, maxLng = lngs.max()!

                let latRange = maxLat - minLat
                let lngRange = maxLng - minLng

                guard latRange > 0, lngRange > 0 else { return }

                let padding: CGFloat = 12
                let drawWidth = size.width - padding * 2
                let drawHeight = size.height - padding * 2

                func point(for coord: CLLocationCoordinate2D) -> CGPoint {
                    let x = padding + CGFloat((coord.longitude - minLng) / lngRange) * drawWidth
                    let y = padding + CGFloat(1.0 - (coord.latitude - minLat) / latRange) * drawHeight
                    return CGPoint(x: x, y: y)
                }

                var path = Path()
                path.move(to: point(for: coordinates[0]))
                for i in 1..<coordinates.count {
                    path.addLine(to: point(for: coordinates[i]))
                }

                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - Google Encoded Polyline Decoder

enum PolylineDecoder {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat: Int = 0
        var lng: Int = 0

        while index < encoded.endIndex {
            // Decode latitude
            var result = 0
            var shift = 0
            var byte: Int
            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex

            let dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dlat

            guard index < encoded.endIndex else { break }

            // Decode longitude
            result = 0
            shift = 0
            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex

            let dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dlng

            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }

        return coordinates
    }

    static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.3 + 0.002,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.3 + 0.002
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Strava Activity Detail Sheet

struct StravaActivityDetailSheet: View {
    let activity: StravaActivity
    let fitnessService: FitnessService

    @Environment(\.dismiss) private var dismiss
    @State private var detail: StravaActivityDetail?
    @State private var isLoading = true

    private let stravaOrange = Color(hex: "FC4C02")

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(stravaOrange)
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            activityHeader
                            if activity.hasRoute, let polyline = activity.map?.summaryPolyline {
                                routeMapSection(polyline)
                            }
                            statsGrid
                            if let segments = detail?.segmentEfforts, !segments.isEmpty {
                                segmentsSection(segments)
                            }
                            if let photo = detail?.photos?.primary, photo.bestURL != nil {
                                photoSection(photo)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(activity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(stravaOrange)
                }
            }
            .task {
                detail = await fitnessService.fetchStravaActivityDetail(activityId: activity.id)
                isLoading = false
            }
        }
    }

    // MARK: - Header

    private var activityHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: activity.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(stravaOrange)
                .frame(width: 50, height: 50)
                .background(stravaOrange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.displayType)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(activity.formattedDistance)
                    .font(.system(size: 14))
                    .foregroundStyle(stravaOrange)

                Text(activity.formattedDuration)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if let kudos = activity.kudosCount, kudos > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                    Text("\(kudos)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(stravaOrange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(stravaOrange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Route Map

    private func routeMapSection(_ polyline: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            PolylineMapPreview(encodedPolyline: polyline, tintColor: stravaOrange)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            if let pace = activity.formattedPace {
                statCard(title: "Pace", value: pace, icon: "speedometer")
            }
            if let elevation = activity.formattedElevation {
                statCard(title: "Elevation", value: elevation, icon: "arrow.up.right")
            }
            if let cal = activity.calories {
                statCard(title: "Calories", value: "\(Int(cal))", icon: "flame")
            }
            if let hr = activity.averageHeartrate {
                statCard(title: "Avg HR", value: "\(Int(hr)) bpm", icon: "heart")
            }
            if let maxHr = activity.maxHeartrate {
                statCard(title: "Max HR", value: "\(Int(maxHr)) bpm", icon: "heart.fill")
            }
            if let maxSpeed = activity.maxSpeed {
                statCard(title: "Max Speed", value: String(format: "%.1f km/h", maxSpeed * 3.6), icon: "gauge.with.dots.needle.67percent")
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(stravaOrange)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Segments

    private func segmentsSection(_ segments: [StravaSegmentEffort]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Segments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(segments.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach(segments.prefix(10)) { segment in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(segment.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(segment.formattedTime)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))

                            if segment.distance > 0 {
                                Text(String(format: "%.1f km", segment.distance / 1000))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    if let prLabel = segment.prLabel {
                        Text(prLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(prLabel == "PR!" ? Color(hex: "FFD700") : .white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(prLabel == "PR!" ? Color(hex: "FFD700").opacity(0.15) : .white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)

                if segment.id != segments.prefix(10).last?.id {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Photo

    private func photoSection(_ photo: StravaPhoto) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity Photo")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            if let url = photo.bestURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    case .failure:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.04))
                            .frame(height: 220)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                    default:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.04))
                            .frame(height: 220)
                            .overlay {
                                ProgressView()
                                    .tint(stravaOrange)
                            }
                    }
                }
            }
        }
    }
}
