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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id may be String or Int from the backend
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }
        name = try container.decode(String.self, forKey: .name)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
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

