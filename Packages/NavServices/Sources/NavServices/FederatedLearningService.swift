import Foundation
import UIKit
import BackgroundTasks
import NavCore
import NavNetworking

@MainActor
public class FederatedLearningService: ObservableObject {

    // MARK: - Published State

    @Published public var isRegistered = false
    @Published public var lastTrainingDate: Date?
    @Published public var sampleCount: Int = 0

    // MARK: - Private State

    private var trainingSamples: [FLTrainingSample] = []
    private var currentWeights: [Double] = Array(repeating: 0.0, count: FLConstants.featureCount)
    private var isTraining = false

    /// Weak reference used by the BGProcessingTask handler to reach the active instance.
    nonisolated(unsafe) static var current: FederatedLearningService?

    // MARK: - Init

    public init() {
        loadLocalState()
        Task { @MainActor in
            Self.current = self
        }
    }

    // MARK: - Device Registration

    public func registerDevice() async {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        do {
            let response: FLRegistrationResponse = try await APIService.shared.post(
                path: "/fl/register",
                body: [
                    "device_id": deviceId,
                    "app_version": appVersion,
                    "platform": "ios",
                ]
            )
            isRegistered = response.success
            NavLog.info("FL device registered: \(response.message ?? "ok")", category: .general)
        } catch {
            NavLog.warning("FL registration failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Sample Collection

    /// Called after each swipe to record a training sample.
    /// liked = true for like/superlike, false for pass.
    public func recordSample(profile: DiscoverProfile, liked: Bool) {
        let features = Self.extractFeatures(from: profile)
        let sample = FLTrainingSample(features: features, liked: liked)
        trainingSamples.append(sample)

        // FIFO eviction
        if trainingSamples.count > FLConstants.maxLocalSamples {
            trainingSamples.removeFirst(trainingSamples.count - FLConstants.maxLocalSamples)
        }

        sampleCount = trainingSamples.count
        saveLocalState()
        NavLog.debug("FL sample recorded (liked=\(liked), total=\(sampleCount))", category: .general)
    }

    // MARK: - Feature Extraction

    /// Maps a DiscoverProfile to a fixed-length [Double] of 28 normalized features.
    /// Feature order must remain stable across app versions for model compatibility.
    public static func extractFeatures(from profile: DiscoverProfile) -> [Double] {
        var f = [Double]()

        // 0: age normalized
        f.append(clamp(Double((profile.age ?? 25) - 18) / 12.0))
        // 1: compatibility score
        f.append(clamp(Double(profile.compatibilityScore ?? 50) / 100.0))
        // 2: isVerified
        f.append(profile.isVerified ? 1.0 : 0.0)
        // 3: isAlumniVerified
        f.append(profile.isAlumniVerified ? 1.0 : 0.0)
        // 4: isProfessionalVerified
        f.append(profile.isProfessionalVerified ? 1.0 : 0.0)
        // 5: isNewInTown
        f.append(profile.isNewInTown ? 1.0 : 0.0)
        // 6: hasVoiceIntro
        f.append(profile.hasVoiceIntro ? 1.0 : 0.0)
        // 7: hasReels
        f.append(profile.hasReels ? 1.0 : 0.0)
        // 8: photo count
        f.append(clamp(Double(min(profile.photos?.count ?? 0, 6)) / 6.0))
        // 9: interests count
        f.append(clamp(Double(min(profile.interests?.count ?? 0, 10)) / 10.0))
        // 10: bio length
        f.append(clamp(Double(min(profile.bio?.count ?? 0, 500)) / 500.0))
        // 11: has bio
        f.append((profile.bio?.isEmpty == false) ? 1.0 : 0.0)
        // 12: has profession
        f.append((profile.profession?.isEmpty == false) ? 1.0 : 0.0)
        // 13: has university
        f.append((profile.university?.isEmpty == false) ? 1.0 : 0.0)
        // 14: has professional org
        f.append((profile.professionalOrg?.isEmpty == false) ? 1.0 : 0.0)
        // 15: languages count
        f.append(clamp(Double(min(profile.languages?.count ?? 0, 5)) / 5.0))
        // 16: has location
        f.append((profile.location?.isEmpty == false) ? 1.0 : 0.0)
        // 17: name length
        f.append(clamp(Double(min(profile.name?.count ?? 0, 30)) / 30.0))
        // 18: graduation recency
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsAgo = Double(max(0, min(10, currentYear - (profile.graduationYear ?? (currentYear - 10)))))
        f.append(clamp(1.0 - yearsAgo / 10.0))
        // 19: has voice intro URL
        f.append((profile.voiceIntroUrl?.isEmpty == false) ? 1.0 : 0.0)
        // 20: verification count
        let verCount = [profile.isVerified, profile.isAlumniVerified, profile.isProfessionalVerified]
            .filter { $0 }.count
        f.append(Double(verCount) / 3.0)
        // 21: profile completeness
        let present: [Bool] = [
            profile.name != nil, profile.age != nil, profile.bio != nil,
            profile.profession != nil, profile.university != nil,
            profile.location != nil, profile.interests?.isEmpty == false,
            profile.photos?.isEmpty == false, profile.languages?.isEmpty == false,
            profile.professionalOrg != nil,
        ]
        f.append(Double(present.filter { $0 }.count) / 10.0)
        // 22: age bucket
        let age = profile.age ?? 25
        if age <= 22 { f.append(0.25) }
        else if age <= 28 { f.append(0.5) }
        else { f.append(1.0) }
        // 23: bio word count
        let wordCount = profile.bio?.split(separator: " ").count ?? 0
        f.append(clamp(Double(min(wordCount, 100)) / 100.0))
        // 24: multi-photo
        f.append((profile.photos?.count ?? 0) > 1 ? 1.0 : 0.0)
        // 25: multi-language
        f.append((profile.languages?.count ?? 0) > 1 ? 1.0 : 0.0)
        // 26: high compatibility
        f.append((profile.compatibilityScore ?? 0) >= 80 ? 1.0 : 0.0)
        // 27: has media content
        f.append((profile.hasVoiceIntro || profile.hasReels) ? 1.0 : 0.0)

        return f
    }

    // MARK: - Training

    /// Pure Swift sigmoid.
    private static func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    /// Pure Swift dot product.
    private static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var result = 0.0
        for i in 0..<a.count {
            result += a[i] * b[i]
        }
        return result
    }

    /// Clamp value to [0, 1].
    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    /// Runs one epoch of SGD over all local training samples.
    /// Returns the weight deltas (new_weights - original_weights).
    public func trainLocally(globalWeights: [Double], learningRate: Double) -> [Double] {
        var weights = globalWeights

        for sample in trainingSamples {
            let prediction = Self.sigmoid(Self.dot(weights, sample.features))
            let error = (sample.liked ? 1.0 : 0.0) - prediction
            for i in 0..<FLConstants.featureCount {
                weights[i] += learningRate * error * sample.features[i]
            }
        }

        // Compute deltas
        var deltas = [Double](repeating: 0.0, count: FLConstants.featureCount)
        for i in 0..<FLConstants.featureCount {
            deltas[i] = weights[i] - globalWeights[i]
        }

        currentWeights = weights
        return deltas
    }

    // MARK: - Round Orchestration

    /// Executes a full FL training round:
    /// 1. Fetch round config (GET /fl/round)
    /// 2. Validate minimum sample count
    /// 3. Train locally with SGD
    /// 4. Upload weight deltas (POST /fl/update)
    public func executeTrainingRound() async {
        guard !isTraining else {
            NavLog.debug("FL training already in progress, skipping", category: .general)
            return
        }
        isTraining = true
        defer { isTraining = false }

        do {
            let roundConfig: FLRoundConfig = try await APIService.shared.get(path: "/fl/round")

            guard trainingSamples.count >= roundConfig.minSamples else {
                NavLog.info("FL: not enough samples (\(trainingSamples.count)/\(roundConfig.minSamples))", category: .general)
                return
            }

            let deltas = trainLocally(
                globalWeights: roundConfig.globalWeights,
                learningRate: roundConfig.learningRate
            )

            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
            let response: FLUpdateResponse = try await APIService.shared.post(
                path: "/fl/update",
                body: [
                    "device_id": deviceId,
                    "round_id": roundConfig.roundId,
                    "weight_deltas": deltas,
                    "sample_count": trainingSamples.count,
                ]
            )

            if response.success {
                NavLog.info("FL round \(roundConfig.roundId) completed, \(trainingSamples.count) samples", category: .general)
                lastTrainingDate = Date()
                trainingSamples.removeAll()
                sampleCount = 0
                saveLocalState()
            } else {
                NavLog.warning("FL update rejected: \(response.message ?? "unknown")", category: .network)
            }
        } catch {
            NavLog.warning("FL training round failed: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Background Task

    /// Register the BGProcessingTask handler. Must be called before app finishes launching.
    public static func registerBackgroundTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: FLConstants.taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            Task { @MainActor in
                if let service = FederatedLearningService.current {
                    await service.handleBackgroundTraining(task: task)
                } else {
                    task.setTaskCompleted(success: false)
                }
            }
        }
        NavLog.debug("FL background task handler registered", category: .general)
    }

    /// Schedule the next background training session.
    public func scheduleBackgroundTraining() {
        let request = BGProcessingTaskRequest(identifier: FLConstants.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
            NavLog.debug("FL background training scheduled", category: .general)
        } catch {
            NavLog.warning("FL background task scheduling failed: \(error.localizedDescription)", category: .general)
        }
    }

    /// Handler invoked by iOS when the BGProcessingTask fires.
    private func handleBackgroundTraining(task: BGProcessingTask) async {
        task.expirationHandler = { [weak self] in
            NavLog.warning("FL background task expired", category: .general)
            Task { @MainActor in
                self?.isTraining = false
            }
        }

        await executeTrainingRound()
        scheduleBackgroundTraining()
        task.setTaskCompleted(success: true)
    }

    // MARK: - Persistence

    private func saveLocalState() {
        LocalCache.shared.save(trainingSamples, forKey: .flTrainingSamples)
        LocalCache.shared.save(currentWeights, forKey: .flWeights)
    }

    private func loadLocalState() {
        if let samples = LocalCache.shared.loadStale([FLTrainingSample].self, forKey: .flTrainingSamples) {
            trainingSamples = samples
            sampleCount = samples.count
        }
        if let weights = LocalCache.shared.loadStale([Double].self, forKey: .flWeights) {
            currentWeights = weights
        }
    }
}
