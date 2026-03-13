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
        // IITs
        UniversitySearchResult(id: "u1", name: "IIT Bombay", shortName: "IITB", city: "Mumbai", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u2", name: "IIT Delhi", shortName: "IITD", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u3", name: "IIT Madras", shortName: "IITM", city: "Chennai", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u4", name: "IIT Kanpur", shortName: "IITK", city: "Kanpur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u5", name: "IIT Kharagpur", shortName: "IITKgp", city: "Kharagpur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u6", name: "IIT Roorkee", shortName: "IITR", city: "Roorkee", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u7", name: "IIT Guwahati", shortName: "IITG", city: "Guwahati", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u8", name: "IIT Hyderabad", shortName: "IITH", city: "Hyderabad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u9", name: "IIT BHU", shortName: "IIT BHU", city: "Varanasi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u10", name: "IIT Indore", shortName: "IITI", city: "Indore", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u11", name: "IIT Dhanbad", shortName: "IIT ISM", city: "Dhanbad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u12", name: "IIT Tirupati", shortName: "IITTP", city: "Tirupati", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u13", name: "IIT Patna", shortName: "IITP", city: "Patna", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u14", name: "IIT Gandhinagar", shortName: "IITGN", city: "Gandhinagar", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u15", name: "IIT Jodhpur", shortName: "IITJ", city: "Jodhpur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u16", name: "IIT Mandi", shortName: "IITMandi", city: "Mandi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u17", name: "IIT Ropar", shortName: "IITRopar", city: "Rupnagar", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u18", name: "IIT Bhubaneswar", shortName: "IITBBS", city: "Bhubaneswar", country: "India", tier: "Top Public"),
        // BITS
        UniversitySearchResult(id: "u19", name: "BITS Pilani", shortName: "BITS", city: "Pilani", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u20", name: "BITS Pilani", shortName: "BITS", city: "Goa", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u21", name: "BITS Pilani", shortName: "BITS", city: "Hyderabad", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u22", name: "BITS Pilani", shortName: "BITS", city: "Dubai", country: "UAE", tier: "Top Private"),
        // NITs
        UniversitySearchResult(id: "u23", name: "NIT Trichy", shortName: "NITT", city: "Tiruchirappalli", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u24", name: "NIT Warangal", shortName: "NITW", city: "Warangal", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u25", name: "NIT Surathkal", shortName: "NITK", city: "Mangalore", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u26", name: "NIT Calicut", shortName: "NITC", city: "Kozhikode", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u27", name: "NIT Rourkela", shortName: "NITR", city: "Rourkela", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u28", name: "NIT Allahabad", shortName: "MNNIT", city: "Prayagraj", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u29", name: "NIT Nagpur", shortName: "VNIT", city: "Nagpur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u30", name: "NIT Jaipur", shortName: "MNIT", city: "Jaipur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u31", name: "NIT Durgapur", shortName: "NITDGP", city: "Durgapur", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u32", name: "NIT Silchar", shortName: "NITS", city: "Silchar", country: "India", tier: "Top Public"),
        // IIITs
        UniversitySearchResult(id: "u33", name: "IIIT Hyderabad", shortName: "IIITH", city: "Hyderabad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u34", name: "IIIT Delhi", shortName: "IIITD", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u35", name: "IIIT Bangalore", shortName: "IIITB", city: "Bangalore", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u36", name: "IIIT Allahabad", shortName: "IIITA", city: "Prayagraj", country: "India", tier: "Top Public"),
        // Central Universities
        UniversitySearchResult(id: "u37", name: "Delhi University", shortName: "DU", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u38", name: "JNU", shortName: "JNU", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u39", name: "BHU", shortName: "BHU", city: "Varanasi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u40", name: "Jamia Millia Islamia", shortName: "JMI", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u41", name: "Aligarh Muslim University", shortName: "AMU", city: "Aligarh", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u42", name: "University of Hyderabad", shortName: "UoH", city: "Hyderabad", country: "India", tier: "Top Public"),
        // Top Private
        UniversitySearchResult(id: "u43", name: "VIT", shortName: "VIT", city: "Vellore", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u44", name: "VIT", shortName: "VIT", city: "Chennai", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u45", name: "VIT-AP", shortName: "VIT-AP", city: "Amaravati", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u46", name: "SRM Institute", shortName: "SRM", city: "Chennai", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u47", name: "Manipal Institute of Technology", shortName: "MIT Manipal", city: "Manipal", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u48", name: "Thapar University", shortName: "Thapar", city: "Patiala", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u49", name: "Amity University", shortName: "Amity", city: "Noida", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u50", name: "LPU", shortName: "LPU", city: "Jalandhar", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u51", name: "Christ University", shortName: nil, city: "Bangalore", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u52", name: "Symbiosis International University", shortName: "SIU", city: "Pune", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u53", name: "Ashoka University", shortName: "Ashoka", city: "Sonipat", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u54", name: "FLAME University", shortName: "FLAME", city: "Pune", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u55", name: "Shiv Nadar University", shortName: "SNU", city: "Greater Noida", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u56", name: "PES University", shortName: "PESU", city: "Bangalore", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u57", name: "RV University", shortName: "RVU", city: "Bangalore", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u58", name: "NMIMS", shortName: "NMIMS", city: "Mumbai", country: "India", tier: "Private"),
        // Vignan
        UniversitySearchResult(id: "u59", name: "Vignan University", shortName: nil, city: "Guntur", country: "India", tier: "Private"),
        UniversitySearchResult(id: "u60", name: "Vignan Institute of Technology and Science", shortName: "VITS", city: "Hyderabad", country: "India", tier: "Private"),
        // State Universities
        UniversitySearchResult(id: "u61", name: "Anna University", shortName: "AU", city: "Chennai", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u62", name: "Savitribai Phule Pune University", shortName: "SPPU", city: "Pune", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u63", name: "Osmania University", shortName: "OU", city: "Hyderabad", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u64", name: "JNTU Hyderabad", shortName: "JNTUH", city: "Hyderabad", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u65", name: "JNTU Kakinada", shortName: "JNTUK", city: "Kakinada", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u66", name: "University of Mumbai", shortName: "MU", city: "Mumbai", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u67", name: "Jadavpur University", shortName: "JU", city: "Kolkata", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u68", name: "Calcutta University", shortName: "CU", city: "Kolkata", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u69", name: "Andhra University", shortName: "AU", city: "Visakhapatnam", country: "India", tier: "Public"),
        UniversitySearchResult(id: "u70", name: "Bangalore University", shortName: "BU", city: "Bangalore", country: "India", tier: "Public"),
        // Medical / Law
        UniversitySearchResult(id: "u71", name: "AIIMS", shortName: "AIIMS", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u72", name: "NLSIU", shortName: "NLS", city: "Bangalore", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u73", name: "NALSAR", shortName: "NALSAR", city: "Hyderabad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u74", name: "NLU Delhi", shortName: "NLU-D", city: "New Delhi", country: "India", tier: "Top Public"),
        // Management
        UniversitySearchResult(id: "u75", name: "IIM Ahmedabad", shortName: "IIMA", city: "Ahmedabad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u76", name: "IIM Bangalore", shortName: "IIMB", city: "Bangalore", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u77", name: "IIM Calcutta", shortName: "IIMC", city: "Kolkata", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u78", name: "ISB", shortName: "ISB", city: "Hyderabad", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u79", name: "XLRI", shortName: "XLRI", city: "Jamshedpur", country: "India", tier: "Top Private"),
        UniversitySearchResult(id: "u80", name: "SP Jain", shortName: "SPJIMR", city: "Mumbai", country: "India", tier: "Top Private"),
        // Design / Arts
        UniversitySearchResult(id: "u81", name: "NID Ahmedabad", shortName: "NID", city: "Ahmedabad", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u82", name: "NIFT Delhi", shortName: "NIFT", city: "New Delhi", country: "India", tier: "Top Public"),
        UniversitySearchResult(id: "u83", name: "FTII", shortName: "FTII", city: "Pune", country: "India", tier: "Top Public"),
        // International
        UniversitySearchResult(id: "u84", name: "MIT", shortName: "MIT", city: "Cambridge", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u85", name: "Stanford University", shortName: "Stanford", city: "Stanford", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u86", name: "NUS", shortName: "NUS", city: "Singapore", country: "Singapore", tier: "Top Public"),
        UniversitySearchResult(id: "u87", name: "NTU", shortName: "NTU", city: "Singapore", country: "Singapore", tier: "Top Public"),
        UniversitySearchResult(id: "u88", name: "Harvard University", shortName: "Harvard", city: "Cambridge", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u89", name: "University of Oxford", shortName: "Oxford", city: "Oxford", country: "UK", tier: "Top Public"),
        UniversitySearchResult(id: "u90", name: "University of Cambridge", shortName: "Cambridge", city: "Cambridge", country: "UK", tier: "Top Public"),
        UniversitySearchResult(id: "u91", name: "University of Toronto", shortName: "UofT", city: "Toronto", country: "Canada", tier: "Top Public"),
        UniversitySearchResult(id: "u92", name: "University of Melbourne", shortName: "UniMelb", city: "Melbourne", country: "Australia", tier: "Top Public"),
        UniversitySearchResult(id: "u93", name: "Carnegie Mellon University", shortName: "CMU", city: "Pittsburgh", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u94", name: "Georgia Tech", shortName: "GT", city: "Atlanta", country: "USA", tier: "Top Public"),
        UniversitySearchResult(id: "u95", name: "UC Berkeley", shortName: "Berkeley", city: "Berkeley", country: "USA", tier: "Top Public"),
        UniversitySearchResult(id: "u96", name: "UCLA", shortName: "UCLA", city: "Los Angeles", country: "USA", tier: "Top Public"),
        UniversitySearchResult(id: "u97", name: "Columbia University", shortName: "Columbia", city: "New York", country: "USA", tier: "Top Private"),
        UniversitySearchResult(id: "u98", name: "University of Waterloo", shortName: "Waterloo", city: "Waterloo", country: "Canada", tier: "Top Public"),
        UniversitySearchResult(id: "u99", name: "ETH Zurich", shortName: "ETH", city: "Zurich", country: "Switzerland", tier: "Top Public"),
        UniversitySearchResult(id: "u100", name: "University of New South Wales", shortName: "UNSW", city: "Sydney", country: "Australia", tier: "Top Public"),
    ]
}
