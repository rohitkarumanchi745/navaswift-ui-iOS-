import Foundation

// MARK: - Ad Placement Configuration (from backend)

public struct AdPlacement: Codable, Identifiable {
    public var id: String { placementId }
    public let placementId: String
    public let adType: AdType
    public let location: String?
    public let admobUnitId: String?
    public let frequencyCapPerHour: Int
    public let cooldownMinutes: Int
    public let enabled: Bool
    public let priority: Int

    public enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case adType = "ad_type"
        case location
        case admobUnitId = "admob_unit_id"
        case frequencyCapPerHour = "frequency_cap_per_hour"
        case cooldownMinutes = "cooldown_minutes"
        case enabled
        case priority
    }

    public init(placementId: String, adType: AdType, location: String? = nil,
                admobUnitId: String? = nil, frequencyCapPerHour: Int = 5,
                cooldownMinutes: Int = 10, enabled: Bool = true, priority: Int = 0) {
        self.placementId = placementId; self.adType = adType; self.location = location
        self.admobUnitId = admobUnitId; self.frequencyCapPerHour = frequencyCapPerHour
        self.cooldownMinutes = cooldownMinutes; self.enabled = enabled; self.priority = priority
    }
}

public enum AdType: String, Codable {
    case native, banner, interstitial, rewarded
}

// MARK: - Placements API Response

public struct AdPlacementsResponse: Codable {
    public let placements: [AdPlacement]
    public let isPremium: Bool?
    public let showAds: Bool?

    public enum CodingKeys: String, CodingKey {
        case placements
        case isPremium = "is_premium"
        case showAds = "show_ads"
    }
}

// MARK: - Impression Tracking

public struct AdImpressionPayload: Codable {
    public let placementId: String
    public let impressionId: String
    public let durationMs: Int?

    public enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case impressionId = "impression_id"
        case durationMs = "duration_ms"
    }

    public init(placementId: String, impressionId: String, durationMs: Int? = nil) {
        self.placementId = placementId
        self.impressionId = impressionId
        self.durationMs = durationMs
    }
}

// MARK: - Rewarded Ad Completion

public struct RewardedAdCompletionPayload: Codable {
    public let placementId: String
    public let impressionId: String
    public let watchedFullDuration: Bool

    public enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case impressionId = "impression_id"
        case watchedFullDuration = "watched_full_duration"
    }
}

public struct RewardedAdResponse: Codable {
    public let granted: Bool
    public let rewardType: String?
    public let rewardAmount: Int?
    public let newBalance: Int?

    public enum CodingKeys: String, CodingKey {
        case granted
        case rewardType = "reward_type"
        case rewardAmount = "reward_amount"
        case newBalance = "new_balance"
    }
}

// MARK: - User Consumable Balances

public struct ConsumableBalances: Codable {
    public let boosts: Int
    public let superLikes: Int
    public let spotlights: Int
    public let extraLikes: Int
    public let profileViews: Int

    public enum CodingKeys: String, CodingKey {
        case boosts
        case superLikes = "super_likes"
        case spotlights
        case extraLikes = "extra_likes"
        case profileViews = "profile_views"
    }

    public init(boosts: Int = 0, superLikes: Int = 0, spotlights: Int = 0,
                extraLikes: Int = 0, profileViews: Int = 0) {
        self.boosts = boosts; self.superLikes = superLikes
        self.spotlights = spotlights; self.extraLikes = extraLikes
        self.profileViews = profileViews
    }
}
