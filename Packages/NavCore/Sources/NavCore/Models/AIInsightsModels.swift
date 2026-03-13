import Foundation

// MARK: - AI Insights Response

public struct AIInsightsResponse: Codable {
    public let compatibilityScore: Int
    public let compatibilityLabel: String
    public let breakdown: AIBreakdown
    public let highlights: AIHighlights

    enum CodingKeys: String, CodingKey {
        case compatibilityScore = "compatibility_score"
        case compatibilityLabel = "compatibility_label"
        case breakdown, highlights
    }
}

public struct AIBreakdown: Codable {
    public let personalityMatch: AIScoreItem
    public let sharedInterests: AIInterestsItem
    public let sharedLanguages: AILanguagesItem
    public let relationshipGoals: AIScoreItem
    public let proximity: AIProximityItem
    public let superLikeBoost: AISuperLikeBoost

    enum CodingKeys: String, CodingKey {
        case personalityMatch = "personality_match"
        case sharedInterests = "shared_interests"
        case sharedLanguages = "shared_languages"
        case relationshipGoals = "relationship_goals"
        case proximity
        case superLikeBoost = "super_like_boost"
    }
}

public struct AIScoreItem: Codable {
    public let score: Int
    public let label: String
    public let weightPct: Int

    enum CodingKeys: String, CodingKey {
        case score, label
        case weightPct = "weight_pct"
    }
}

public struct AIInterestsItem: Codable {
    public let score: Int
    public let label: String
    public let shared: [String]?
    public let weightPct: Int

    enum CodingKeys: String, CodingKey {
        case score, label, shared
        case weightPct = "weight_pct"
    }
}

public struct AILanguagesItem: Codable {
    public let score: Int
    public let label: String
    public let shared: [String]?
    public let weightPct: Int

    enum CodingKeys: String, CodingKey {
        case score, label, shared
        case weightPct = "weight_pct"
    }
}

public struct AIProximityItem: Codable {
    public let score: Int
    public let label: String
    public let distanceKm: Double?
    public let weightPct: Int

    enum CodingKeys: String, CodingKey {
        case score, label
        case distanceKm = "distance_km"
        case weightPct = "weight_pct"
    }
}

public struct AISuperLikeBoost: Codable {
    public let active: Bool
    public let label: String
}

public struct AIHighlights: Codable {
    public let sameUniversity: Bool?
    public let university: String?
    public let cfSignal: Bool?
    public let cfLabel: String?

    enum CodingKeys: String, CodingKey {
        case sameUniversity = "same_university"
        case university
        case cfSignal = "cf_signal"
        case cfLabel = "cf_label"
    }
}

// MARK: - Demo Data

public extension AIInsightsResponse {
    static let demo = AIInsightsResponse(
        compatibilityScore: 78,
        compatibilityLabel: "Strong compatibility",
        breakdown: AIBreakdown(
            personalityMatch: AIScoreItem(score: 82, label: "Your profiles are highly aligned", weightPct: 55),
            sharedInterests: AIInterestsItem(score: 60, label: "Good interest overlap", shared: ["hiking", "music"], weightPct: 10),
            sharedLanguages: AILanguagesItem(score: 100, label: "You speak the same language", shared: ["English"], weightPct: 5),
            relationshipGoals: AIScoreItem(score: 100, label: "Same relationship goals", weightPct: 5),
            proximity: AIProximityItem(score: 85, label: "12 km away", distanceKm: 12.3, weightPct: 20),
            superLikeBoost: AISuperLikeBoost(active: false, label: "No super like")
        ),
        highlights: AIHighlights(
            sameUniversity: true,
            university: "IIT Bombay",
            cfSignal: true,
            cfLabel: "Some mutual connections liked them"
        )
    )
}
