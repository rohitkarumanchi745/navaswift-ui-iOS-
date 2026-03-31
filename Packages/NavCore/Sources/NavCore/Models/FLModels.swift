import Foundation

// MARK: - Constants

public enum FLConstants {
    public static let featureCount = 28
    public static let taskIdentifier = "com.nava.app.fl-training"
    /// Maximum samples to retain locally before oldest are evicted.
    public static let maxLocalSamples = 500
}

// MARK: - Training Sample

/// A single (features, label) pair collected from a swipe interaction.
public struct FLTrainingSample: Codable, Identifiable {
    public let id: UUID
    public let features: [Double]
    public let liked: Bool
    public let timestamp: Date

    public init(features: [Double], liked: Bool) {
        self.id = UUID()
        self.features = features
        self.liked = liked
        self.timestamp = Date()
    }
}

// MARK: - Round Configuration

/// Returned by GET /fl/round — describes the current global training round.
public struct FLRoundConfig: Codable {
    public let roundId: Int
    public let globalWeights: [Double]
    public let learningRate: Double
    public let minSamples: Int

    enum CodingKeys: String, CodingKey {
        case roundId = "round_id"
        case globalWeights = "global_weights"
        case learningRate = "learning_rate"
        case minSamples = "min_samples"
    }
}

// MARK: - Device Registration

/// Payload for POST /fl/register.
public struct FLDeviceRegistration: Codable {
    public let deviceId: String
    public let appVersion: String
    public let platform: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case appVersion = "app_version"
        case platform
    }

    public init(deviceId: String, appVersion: String) {
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.platform = "ios"
    }
}

/// Response from POST /fl/register.
public struct FLRegistrationResponse: Codable {
    public let success: Bool
    public let message: String?
}

// MARK: - Weight Update

/// Payload for POST /fl/update — sends weight deltas, not raw weights.
public struct FLUpdatePayload: Codable {
    public let deviceId: String
    public let roundId: Int
    public let weightDeltas: [Double]
    public let sampleCount: Int

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case roundId = "round_id"
        case weightDeltas = "weight_deltas"
        case sampleCount = "sample_count"
    }
}

/// Response from POST /fl/update.
public struct FLUpdateResponse: Codable {
    public let success: Bool
    public let message: String?
}
