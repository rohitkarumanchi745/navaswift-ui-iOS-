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

// MARK: - Demo Data

public extension SearchSuggestions {
    private static let demoUniversities: [TrendingUniversity] = [
        TrendingUniversity(id: "1", name: "IIT Bombay", studentCount: 342),
        TrendingUniversity(id: "2", name: "IIT Delhi", studentCount: 312),
        TrendingUniversity(id: "3", name: "BITS Pilani", studentCount: 289),
        TrendingUniversity(id: "4", name: "IIT Madras", studentCount: 267),
        TrendingUniversity(id: "5", name: "VIT", studentCount: 245),
        TrendingUniversity(id: "6", name: "NIT Trichy", studentCount: 234),
        TrendingUniversity(id: "7", name: "IIT Kanpur", studentCount: 223),
        TrendingUniversity(id: "8", name: "IIT Kharagpur", studentCount: 218),
        TrendingUniversity(id: "9", name: "MIT", studentCount: 218),
        TrendingUniversity(id: "10", name: "Delhi University", studentCount: 198),
        TrendingUniversity(id: "11", name: "SRM Institute", studentCount: 187),
        TrendingUniversity(id: "12", name: "NIT Warangal", studentCount: 178),
        TrendingUniversity(id: "13", name: "IIIT Hyderabad", studentCount: 165),
        TrendingUniversity(id: "14", name: "NUS", studentCount: 156),
        TrendingUniversity(id: "15", name: "IIT Hyderabad", studentCount: 145),
        TrendingUniversity(id: "16", name: "Manipal Institute of Technology", studentCount: 134),
        TrendingUniversity(id: "17", name: "PES University", studentCount: 123),
        TrendingUniversity(id: "18", name: "Vignan University", studentCount: 112),
        TrendingUniversity(id: "19", name: "JNTU Hyderabad", studentCount: 108),
        TrendingUniversity(id: "20", name: "Stanford", studentCount: 97),
    ]

    private static let demoCities: [TopCity] = [
        TopCity(name: "Bangalore", studentCount: 234),
        TopCity(name: "Delhi", studentCount: 189),
        TopCity(name: "Mumbai", studentCount: 156),
        TopCity(name: "Austin", studentCount: 98),
        TopCity(name: "Hyderabad", studentCount: 167),
        TopCity(name: "Chennai", studentCount: 134),
    ]

    private static let demoCountries: [SearchCountry] = [
        SearchCountry(code: "IND", name: "India", flag: "🇮🇳", studentCount: 1204),
        SearchCountry(code: "USA", name: "USA", flag: "🇺🇸", studentCount: 892),
        SearchCountry(code: "GBR", name: "UK", flag: "🇬🇧", studentCount: 341),
        SearchCountry(code: "AUS", name: "Australia", flag: "🇦🇺", studentCount: 127),
    ]

    static let demo = SearchSuggestions(
        trendingUniversities: demoUniversities,
        topCities: demoCities,
        countries: demoCountries
    )
}

public extension StudentResult {
    static let demos: [StudentResult] = {
        let s1 = StudentResult(id: "s1", name: "Priya", age: 22, photos: ["https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400"], university: "IIT Bombay", universityTier: "Top Public", study: "Computer Science", city: "Mumbai", country: "India", distance: 2.3, bio: "Coffee lover, code writer", isVerified: true, isAlumni: false, graduationYear: 2027, canMessage: false, interactionStatus: "none")
        let s2 = StudentResult(id: "s2", name: "Rahul", age: 24, photos: ["https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400"], university: "BITS Pilani", universityTier: "Top Private", study: "Electrical Engineering", city: "Bangalore", country: "India", distance: nil, bio: "Building the future, one line at a time", isVerified: true, isAlumni: true, graduationYear: 2024, canMessage: false, interactionStatus: "none")
        let s3 = StudentResult(id: "s3", name: "Ananya", age: 23, photos: ["https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400"], university: "NUS", universityTier: "Top Public", study: "Business Analytics", city: "Singapore", country: "Singapore", distance: nil, bio: "Globetrotter and bookworm", isVerified: false, isAlumni: false, graduationYear: 2026, canMessage: false, interactionStatus: "liked")
        let s4 = StudentResult(id: "s4", name: "Meera", age: 21, photos: ["https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400"], university: "IIT Delhi", universityTier: "Top Public", study: "Mathematics", city: "Delhi", country: "India", distance: 5.1, bio: "Music and math", isVerified: true, isAlumni: false, graduationYear: 2028, canMessage: true, interactionStatus: "matched")
        let s5 = StudentResult(id: "s5", name: "Rohit", age: 23, photos: ["https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400"], university: "IIT Bombay", universityTier: "Top Public", study: "Mechanical Engineering", city: "Mumbai", country: "India", distance: 3.5, bio: "Weekend biker, weekday coder", isVerified: true, isAlumni: false, graduationYear: 2026, canMessage: false, interactionStatus: "none")
        let s6 = StudentResult(id: "s6", name: "Anika", age: 21, photos: ["https://images.unsplash.com/photo-1504703395950-b89145a5425b?w=400"], university: "IIT Bombay", universityTier: "Top Public", study: "Data Science", city: "Mumbai", country: "India", distance: 1.8, bio: "Data nerd with a travel bug", isVerified: true, isAlumni: false, graduationYear: 2028, canMessage: false, interactionStatus: "none")
        let s7 = StudentResult(id: "s7", name: "Sneha", age: 23, photos: ["https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400"], university: "BITS Pilani", universityTier: "Top Private", study: "Chemical Engineering", city: "Pilani", country: "India", distance: 12.0, bio: "Foodie and aspiring chef", isVerified: false, isAlumni: true, graduationYear: 2023, canMessage: false, interactionStatus: "none")
        let s8 = StudentResult(id: "s8", name: "Rohit Krishna", age: 25, photos: ["https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400"], university: "IIT Delhi", universityTier: "Top Public", study: "Physics", city: "Delhi", country: "India", distance: 4.2, bio: "Quantum physics meets guitar", isVerified: true, isAlumni: true, graduationYear: 2024, canMessage: false, interactionStatus: "none")
        return [s1, s2, s3, s4, s5, s6, s7, s8]
    }()
}
