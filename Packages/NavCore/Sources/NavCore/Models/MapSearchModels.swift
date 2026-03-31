import Foundation

// MARK: - Map Search (POST /map/search)

public struct MapSearchRequest: Codable {
    public let query: String?
    public let latitude: Double
    public let longitude: Double
    public let placeId: String?
    public let placeName: String?
    public let category: String?
    public let navigated: Bool

    public init(
        query: String? = nil,
        latitude: Double,
        longitude: Double,
        placeId: String? = nil,
        placeName: String? = nil,
        category: String? = nil,
        navigated: Bool = false
    ) {
        self.query = query
        self.latitude = latitude
        self.longitude = longitude
        self.placeId = placeId
        self.placeName = placeName
        self.category = category
        self.navigated = navigated
    }

    private enum CodingKeys: String, CodingKey {
        case query, latitude, longitude, category, navigated
        case placeId = "place_id"
        case placeName = "place_name"
    }
}

public struct MapSearchResponse: Codable {
    public let success: Bool?
    public let message: String?
}

// MARK: - Trending Places (GET /map/trending)

public struct MapTrendingResponse: Codable {
    public let places: [TrendingPlace]
}

public struct TrendingPlace: Codable, Identifiable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let category: String?
    public let searchCount: Int
    public let navigatedCount: Int
    public let trendingScore: Double?

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, category
        case searchCount = "search_count"
        case navigatedCount = "navigated_count"
        case trendingScore = "trending_score"
    }

    public var iconName: String {
        switch category?.lowercased() {
        case "restaurant", "cafe", "food": return "fork.knife"
        case "park", "garden": return "leaf.fill"
        case "landmark", "monument": return "building.columns.fill"
        case "bar", "nightlife": return "wineglass.fill"
        case "gym", "fitness": return "dumbbell.fill"
        case "shopping", "mall": return "bag.fill"
        case "viewpoint", "scenic": return "binoculars.fill"
        case "trail", "hike": return "figure.hiking"
        case "lake", "beach": return "water.waves"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - Explorer Interests (GET /map/interests)

public struct ExplorerInterestsResponse: Codable {
    public let explorerType: String
    public let explorerEmoji: String
    public let topCategories: [ExplorerCategory]
    public let totalSearches: Int
    public let totalNavigations: Int
    public let topPlaces: [ExplorerTopPlace]?

    private enum CodingKeys: String, CodingKey {
        case explorerType = "explorer_type"
        case explorerEmoji = "explorer_emoji"
        case topCategories = "top_categories"
        case totalSearches = "total_searches"
        case totalNavigations = "total_navigations"
        case topPlaces = "top_places"
    }
}

public struct ExplorerCategory: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let count: Int
    public let percentage: Double?
}

public struct ExplorerTopPlace: Codable, Identifiable {
    public let id: String
    public let name: String
    public let visitCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, name
        case visitCount = "visit_count"
    }
}
