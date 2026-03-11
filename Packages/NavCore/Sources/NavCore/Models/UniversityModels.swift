import Foundation

// MARK: - University Search Response

public struct UniversitySearchResult: Decodable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let shortName: String?
    public let city: String?
    public let country: String?
    public let tier: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, city, country, tier
        case shortName = "short_name"
    }

    /// Display string like "BITS Pilani - Goa" or "IIT Bombay"
    public var displayName: String {
        if let city, !city.isEmpty, !name.lowercased().contains(city.lowercased()) {
            return "\(name) - \(city)"
        }
        return name
    }
}

public struct UniversitySearchResponse: Decodable {
    public let universities: [UniversitySearchResult]
}

// MARK: - Common Fields of Study

public struct StudyFields {
    public static let all: [String] = [
        "Computer Science",
        "Electrical Engineering",
        "Mechanical Engineering",
        "Civil Engineering",
        "Chemical Engineering",
        "Electronics & Communication",
        "Information Technology",
        "Data Science",
        "Artificial Intelligence",
        "Business Administration",
        "Commerce",
        "Economics",
        "Finance",
        "Marketing",
        "Medicine",
        "Pharmacy",
        "Nursing",
        "Dentistry",
        "Law",
        "Arts & Humanities",
        "English Literature",
        "Psychology",
        "Sociology",
        "Political Science",
        "History",
        "Philosophy",
        "Mathematics",
        "Physics",
        "Chemistry",
        "Biology",
        "Biotechnology",
        "Environmental Science",
        "Architecture",
        "Design",
        "Media & Communication",
        "Journalism",
        "Education",
        "Agriculture",
        "Aerospace Engineering",
        "Business Analytics",
    ]
}

// MARK: - Demo Data

public extension UniversitySearchResult {
    static let demos: [UniversitySearchResult] = [
        UniversitySearchResult(id: "u1", name: "IIT Bombay", shortName: "IITB", city: "Mumbai", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u2", name: "IIT Delhi", shortName: "IITD", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u3", name: "IIT Madras", shortName: "IITM", city: "Chennai", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u4", name: "IIT Kanpur", shortName: "IITK", city: "Kanpur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u5", name: "BITS Pilani", shortName: "BITS", city: "Pilani", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u6", name: "BITS Pilani", shortName: "BITS", city: "Goa", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u7", name: "BITS Pilani", shortName: "BITS", city: "Hyderabad", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u8", name: "NIT Trichy", shortName: "NITT", city: "Tiruchirappalli", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u9", name: "NIT Warangal", shortName: "NITW", city: "Warangal", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u10", name: "Vignan University", shortName: nil, city: "Guntur", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u11", name: "VIT", shortName: "VIT", city: "Vellore", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u12", name: "VIT", shortName: "VIT", city: "Chennai", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u13", name: "MIT", shortName: "MIT", city: "Cambridge", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u14", name: "Stanford University", shortName: "Stanford", city: "Stanford", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u15", name: "NUS", shortName: "NUS", city: "Singapore", country: "Singapore", tier: "Top Public"),
    ]
}
