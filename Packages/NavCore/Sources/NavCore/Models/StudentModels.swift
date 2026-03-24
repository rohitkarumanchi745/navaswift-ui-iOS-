import Foundation

// MARK: - Search Suggestions

public struct SearchSuggestions: Decodable {
    public let trendingUniversities: [TrendingUniversity]?
    public let topCities: [TopCity]?
    public let countries: [SearchCountry]?

    public struct TrendingUniversity: Decodable, Identifiable {
        public let id: String
        public let name: String
        public let studentCount: Int?

        private enum CodingKeys: String, CodingKey {
            case id, name
            case studentCount = "student_count"
        }
    }

    public struct TopCity: Decodable, Identifiable {
        public var id: String { name }
        public let name: String
        public let studentCount: Int?

        private enum CodingKeys: String, CodingKey {
            case name
            case studentCount = "student_count"
        }
    }

    public struct SearchCountry: Decodable, Identifiable {
        public var id: String { code }
        public let code: String
        public let name: String
        public let flag: String?
        public let studentCount: Int?

        private enum CodingKeys: String, CodingKey {
            case code, name, flag
            case studentCount = "student_count"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case trendingUniversities = "trending_universities"
        case topCities = "top_cities"
        case countries
    }
}

// MARK: - Search Response

public struct StudentSearchResponse: Decodable {
    public let students: [StudentResult]?
    public let total: Int?
    public let isPremium: Bool?

    private enum CodingKeys: String, CodingKey {
        case students, total
        case isPremium = "is_premium"
    }
}

public struct StudentResult: Decodable, Identifiable {
    public let id: String
    public let name: String?
    public let age: Int?
    public let photos: [String]?
    public let university: String?
    public let universityTier: String?
    public let study: String?
    public let city: String?
    public let country: String?
    public let distance: Double?
    public let bio: String?
    public let isVerified: Bool?
    public let isAlumni: Bool?
    public let graduationYear: Int?
    public let canMessage: Bool?
    public var interactionStatus: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, age, photos, university, study, city, country, distance, bio
        case universityTier = "university_tier"
        case isVerified = "is_verified"
        case isAlumni = "is_alumni"
        case graduationYear = "graduation_year"
        case canMessage = "can_message"
        case interactionStatus = "interaction_status"
    }
}

// MARK: - Like Response

public struct StudentLikeResponse: Decodable {
    public let liked: Bool?
    public let isMatch: Bool?
    public let matchId: String?

    private enum CodingKeys: String, CodingKey {
        case liked
        case isMatch = "is_match"
        case matchId = "match_id"
    }
}

// MARK: - Filters

public struct StudentFilters {
    public var university: String = ""
    public var city: String = ""
    public var country: String = ""
    public var gender: String = ""
    public var minAge: Int = 18
    public var maxAge: Int = 30
    public var tier: String = ""
    public var classYear: String = ""
    public var alumniOnly: Bool = false

    public init() {}

    public var hasActive: Bool {
        !university.isEmpty || !city.isEmpty || !country.isEmpty ||
        !gender.isEmpty || !tier.isEmpty || minAge != 18 || maxAge != 30 ||
        !classYear.isEmpty || alumniOnly
    }

    public func queryString() -> String {
        var params: [String] = []
        if !university.isEmpty { params.append("university=\(university.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? university)") }
        if !city.isEmpty { params.append("city=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)") }
        if !country.isEmpty { params.append("country=\(country)") }
        if !gender.isEmpty { params.append("gender=\(gender)") }
        if minAge != 18 { params.append("min_age=\(minAge)") }
        if maxAge != 30 { params.append("max_age=\(maxAge)") }
        if !tier.isEmpty { params.append("tier=\(tier)") }
        if !classYear.isEmpty { params.append("class_year=\(classYear)") }
        if alumniOnly { params.append("alumni_only=true") }
        return params.isEmpty ? "" : "&\(params.joined(separator: "&"))"
    }
}

