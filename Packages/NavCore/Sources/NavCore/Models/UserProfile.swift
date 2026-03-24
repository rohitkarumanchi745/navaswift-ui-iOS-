import Foundation
import SwiftUI

public struct UserProfile: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String?
    public var phoneNumber: String?
    public var dob: String?
    public var age: Int?
    public var gender: String?
    public var bio: String?
    public var location: String?
    public var profession: String?
    public var professionCategory: String?
    public var professionTitle: String?
    public var interests: [String]?
    public var photos: [String]?
    public var isProfileComplete: Bool?
    public var isVerified: Bool?
    public var isStudentVerified: Bool?
    public var studentVerificationMethod: String?  // "email", "student_id", "enrollment_doc", "campus", "lms"
    public var isAlumniVerified: Bool?
    public var isProfessionalVerified: Bool?
    public var isNewInTown: Bool?
    public var graduationYear: Int?
    public var professionalOrg: String?
    public var joinedLocationDate: String?
    public var heightCm: Int?
    public var languages: [String]?
    public var lookingFor: String?
    public var voiceIntroUrl: String?
    public var university: String?
    public var universityLocation: String?
    public var study: String?

    enum CodingKeys: String, CodingKey {
        case id, name, dob, age, gender, bio, location, profession, interests, languages, university, study
        case phoneNumber = "phone_number"
        case professionCategory = "profession_category"
        case professionTitle = "profession_title"
        case photos
        case isProfileComplete = "is_profile_complete"
        case isVerified = "is_verified"
        case isStudentVerified = "is_student_verified"
        case studentVerificationMethod = "student_verification_method"
        case isAlumniVerified = "is_alumni_verified"
        case isProfessionalVerified = "is_professional_verified"
        case isNewInTown = "is_new_in_town"
        case graduationYear = "graduation_year"
        case professionalOrg = "professional_org"
        case joinedLocationDate = "joined_location_date"
        case heightCm = "height_cm"
        case lookingFor = "looking_for"
        case voiceIntroUrl = "voice_intro_url"
        case universityLocation = "university_location"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = ""
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        dob = try container.decodeIfPresent(String.self, forKey: .dob)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        profession = try container.decodeIfPresent(String.self, forKey: .profession)
        professionCategory = try container.decodeIfPresent(String.self, forKey: .professionCategory)
        professionTitle = try container.decodeIfPresent(String.self, forKey: .professionTitle)
        interests = try container.decodeIfPresent([String].self, forKey: .interests)
        photos = try container.decodeIfPresent([String].self, forKey: .photos)
        isProfileComplete = try container.decodeIfPresent(Bool.self, forKey: .isProfileComplete)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        isStudentVerified = try container.decodeIfPresent(Bool.self, forKey: .isStudentVerified)
        studentVerificationMethod = try container.decodeIfPresent(String.self, forKey: .studentVerificationMethod)
        isAlumniVerified = try container.decodeIfPresent(Bool.self, forKey: .isAlumniVerified)
        isProfessionalVerified = try container.decodeIfPresent(Bool.self, forKey: .isProfessionalVerified)
        isNewInTown = try container.decodeIfPresent(Bool.self, forKey: .isNewInTown)
        graduationYear = try container.decodeIfPresent(Int.self, forKey: .graduationYear)
        professionalOrg = try container.decodeIfPresent(String.self, forKey: .professionalOrg)
        joinedLocationDate = try container.decodeIfPresent(String.self, forKey: .joinedLocationDate)
        heightCm = try container.decodeIfPresent(Int.self, forKey: .heightCm)
        languages = try container.decodeIfPresent([String].self, forKey: .languages)
        lookingFor = try container.decodeIfPresent(String.self, forKey: .lookingFor)
        voiceIntroUrl = try container.decodeIfPresent(String.self, forKey: .voiceIntroUrl)
        university = try container.decodeIfPresent(String.self, forKey: .university)
        universityLocation = try container.decodeIfPresent(String.self, forKey: .universityLocation)
        study = try container.decodeIfPresent(String.self, forKey: .study)
    }

    public init(id: String, name: String? = nil, phoneNumber: String? = nil, dob: String? = nil,
                age: Int? = nil, gender: String? = nil, bio: String? = nil, location: String? = nil,
                profession: String? = nil, professionCategory: String? = nil, professionTitle: String? = nil,
                interests: [String]? = nil, photos: [String]? = nil, isProfileComplete: Bool? = nil,
                isVerified: Bool? = nil, isStudentVerified: Bool? = nil, studentVerificationMethod: String? = nil,
                isAlumniVerified: Bool? = nil, isProfessionalVerified: Bool? = nil,
                isNewInTown: Bool? = nil, graduationYear: Int? = nil,
                professionalOrg: String? = nil, joinedLocationDate: String? = nil,
                heightCm: Int? = nil,
                languages: [String]? = nil, lookingFor: String? = nil, voiceIntroUrl: String? = nil,
                university: String? = nil, universityLocation: String? = nil, study: String? = nil) {
        self.id = id; self.name = name; self.phoneNumber = phoneNumber; self.dob = dob
        self.age = age; self.gender = gender; self.bio = bio; self.location = location
        self.profession = profession; self.professionCategory = professionCategory
        self.professionTitle = professionTitle; self.interests = interests; self.photos = photos
        self.isProfileComplete = isProfileComplete; self.isVerified = isVerified
        self.isStudentVerified = isStudentVerified; self.studentVerificationMethod = studentVerificationMethod
        self.isAlumniVerified = isAlumniVerified; self.isProfessionalVerified = isProfessionalVerified
        self.isNewInTown = isNewInTown; self.graduationYear = graduationYear
        self.professionalOrg = professionalOrg; self.joinedLocationDate = joinedLocationDate
        self.heightCm = heightCm
        self.languages = languages; self.lookingFor = lookingFor; self.voiceIntroUrl = voiceIntroUrl
        self.university = university; self.universityLocation = universityLocation; self.study = study
    }

    public var displayName: String { name ?? "User" }
    public var firstName: String { name?.components(separatedBy: " ").first ?? "User" }
    public var primaryPhoto: String? { photos?.first }

    public var profileCompletion: Int {
        let sections: [Any?] = [name, dob, bio, photos?.isEmpty == false ? photos : nil]
        let completed = sections.compactMap { $0 }.count
        return min(100, Int((Double(completed) / Double(sections.count)) * 100))
    }
}

public struct DiscoverProfile: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String?
    public var age: Int?
    public var location: String?
    public var profession: String?
    public var compatibilityScore: Int?
    public var bio: String?
    public var interests: [String]?
    public var photos: [String]?
    public var isVerified: Bool
    public var isAlumniVerified: Bool
    public var isProfessionalVerified: Bool
    public var isNewInTown: Bool
    public var graduationYear: Int?
    public var university: String?
    public var professionalOrg: String?
    public var voiceIntroUrl: String?
    public var hasVoiceIntro: Bool
    public var hasReels: Bool
    public var languages: [String]?

    public var primaryPhoto: String? { photos?.first }

    enum CodingKeys: String, CodingKey {
        case id, name, age, location, bio, interests, languages, university
        case profession = "profession_title"
        case compatibilityScore = "compatibility_score"
        case photos
        case isVerified = "is_verified"
        case isAlumniVerified = "is_alumni_verified"
        case isProfessionalVerified = "is_professional_verified"
        case isNewInTown = "is_new_in_town"
        case graduationYear = "graduation_year"
        case professionalOrg = "professional_org"
        case voiceIntroUrl = "voice_intro_url"
        case hasVoiceIntro = "has_voice_intro"
        case hasReels = "has_reels"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = ""
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
        age = try container.decodeIfPresent(Int.self, forKey: .age)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        profession = try container.decodeIfPresent(String.self, forKey: .profession)
        compatibilityScore = try container.decodeIfPresent(Int.self, forKey: .compatibilityScore)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        interests = try container.decodeIfPresent([String].self, forKey: .interests)
        photos = try container.decodeIfPresent([String].self, forKey: .photos)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isAlumniVerified = try container.decodeIfPresent(Bool.self, forKey: .isAlumniVerified) ?? false
        isProfessionalVerified = try container.decodeIfPresent(Bool.self, forKey: .isProfessionalVerified) ?? false
        isNewInTown = try container.decodeIfPresent(Bool.self, forKey: .isNewInTown) ?? false
        graduationYear = try container.decodeIfPresent(Int.self, forKey: .graduationYear)
        university = try container.decodeIfPresent(String.self, forKey: .university)
        professionalOrg = try container.decodeIfPresent(String.self, forKey: .professionalOrg)
        voiceIntroUrl = try container.decodeIfPresent(String.self, forKey: .voiceIntroUrl)
        hasVoiceIntro = try container.decodeIfPresent(Bool.self, forKey: .hasVoiceIntro) ?? false
        hasReels = try container.decodeIfPresent(Bool.self, forKey: .hasReels) ?? false
        languages = try container.decodeIfPresent([String].self, forKey: .languages)
    }

    public init(id: String, name: String? = nil, age: Int? = nil, location: String? = nil,
                profession: String? = nil, compatibilityScore: Int? = nil, bio: String? = nil,
                interests: [String]? = nil, photos: [String]? = nil, isVerified: Bool = false,
                isAlumniVerified: Bool = false, isProfessionalVerified: Bool = false,
                isNewInTown: Bool = false, graduationYear: Int? = nil, university: String? = nil,
                professionalOrg: String? = nil,
                voiceIntroUrl: String? = nil, hasVoiceIntro: Bool = false, hasReels: Bool = false,
                languages: [String]? = nil) {
        self.id = id; self.name = name; self.age = age; self.location = location
        self.profession = profession; self.compatibilityScore = compatibilityScore; self.bio = bio
        self.interests = interests; self.photos = photos; self.isVerified = isVerified
        self.isAlumniVerified = isAlumniVerified; self.isProfessionalVerified = isProfessionalVerified
        self.isNewInTown = isNewInTown; self.graduationYear = graduationYear
        self.university = university; self.professionalOrg = professionalOrg
        self.voiceIntroUrl = voiceIntroUrl; self.hasVoiceIntro = hasVoiceIntro
        self.hasReels = hasReels; self.languages = languages
    }

    public static func == (lhs: DiscoverProfile, rhs: DiscoverProfile) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct MatchProfile: Identifiable, Codable {
    public let id: String
    public let matchId: String
    public var name: String
    public var age: Int
    public var photo: String
    public var lastMessage: String?
    public var timestamp: String?
    public var unreadCount: Int
    public var isOnline: Bool
    public var isMutual: Bool
    public var lastSeen: Date?

    public init(id: String, matchId: String, name: String, age: Int, photo: String,
                lastMessage: String? = nil, timestamp: String? = nil, unreadCount: Int = 0,
                isOnline: Bool = false, isMutual: Bool = false, lastSeen: Date? = nil) {
        self.id = id; self.matchId = matchId; self.name = name; self.age = age; self.photo = photo
        self.lastMessage = lastMessage; self.timestamp = timestamp; self.unreadCount = unreadCount
        self.isOnline = isOnline; self.isMutual = isMutual; self.lastSeen = lastSeen
    }

    /// Human-readable "last seen" string, e.g. "Last seen 5 min ago", "Last seen yesterday"
    public var lastSeenText: String {
        guard !isOnline else { return "Online" }
        guard let lastSeen else { return "Last seen recently" }
        let interval = Date().timeIntervalSince(lastSeen)
        if interval < 60 { return "Last seen just now" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "Last seen \(mins) min ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Last seen \(hours)h ago"
        }
        if interval < 172800 { return "Last seen yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Last seen \(formatter.string(from: lastSeen))"
    }
}

public struct ChatMessage: Identifiable, Equatable {
    public let id: String
    public let matchId: String
    public let senderId: Int
    public let receiverId: Int
    public var content: String
    public var createdAt: Date?
    public var status: MessageStatus

    public enum MessageStatus: String {
        case sending, sent, delivered, read
    }

    public init(id: String, matchId: String, senderId: Int, receiverId: Int,
                content: String, createdAt: Date? = nil, status: MessageStatus = .sending) {
        self.id = id; self.matchId = matchId; self.senderId = senderId; self.receiverId = receiverId
        self.content = content; self.createdAt = createdAt; self.status = status
    }

}

public struct LikedProfile: Identifiable {
    public let id: String
    public var name: String
    public var age: Int
    public var photo: String
    public var type: LikeType
    public var likedAt: String
    public var message: String?

    public enum LikeType: String {
        case swipe, reel, superLike = "super_like"
    }

    public init(id: String, name: String, age: Int, photo: String, type: LikeType, likedAt: String, message: String? = nil) {
        self.id = id; self.name = name; self.age = age; self.photo = photo
        self.type = type; self.likedAt = likedAt; self.message = message
    }
}

// MARK: - Country Model
public struct Country: Identifiable, Equatable {
    public let id: String
    public let code: String
    public let name: String
    public let dialCode: String
    public let flag: String
    public let minLength: Int
    public let maxLength: Int

    public init(id: String, code: String, name: String, dialCode: String, flag: String, minLength: Int, maxLength: Int) {
        self.id = id; self.code = code; self.name = name; self.dialCode = dialCode
        self.flag = flag; self.minLength = minLength; self.maxLength = maxLength
    }
}

// MARK: - Premium Tier (bridges UI config to StoreKit product IDs)
public enum PremiumTier: String, CaseIterable, Identifiable {
    case gold, platinum, ultra
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .ultra: return "Ultra"
        }
    }

    public var storeProductID: String {
        switch self {
        case .gold: return StoreProductID.goldMonthly.rawValue
        case .platinum: return StoreProductID.platinumMonthly.rawValue
        case .ultra: return StoreProductID.ultraMonthly.rawValue
        }
    }

    public var icon: String {
        switch self {
        case .gold: return "star.fill"
        case .platinum: return "crown.fill"
        case .ultra: return "diamond.fill"
        }
    }

    public var badge: String? {
        switch self {
        case .platinum: return "POPULAR"
        case .ultra: return "BEST VALUE"
        default: return nil
        }
    }

    public var accentColor: Color {
        switch self {
        case .gold: return Color(hex: "D4AF37")
        case .platinum: return Color(hex: "845EC2")
        case .ultra: return Color(hex: "4ECDC4")
        }
    }

    public var features: [String] {
        switch self {
        case .gold:
            return ["Unlimited likes", "See who likes you", "5 Super Likes/day",
                    "1 free Boost/month", "Advanced filters"]
        case .platinum:
            return ["All Gold features", "Priority matching", "Read receipts",
                    "Weekly boost included", "Undo last swipe"]
        case .ultra:
            return ["All Platinum features", "Priority support", "Exclusive events",
                    "See all likes instantly", "Unlimited Super Likes"]
        }
    }
}

public extension Country {
    static let all: [Country] = [
        Country(id: "IN", code: "IN", name: "India", dialCode: "+91", flag: "\u{1F1EE}\u{1F1F3}", minLength: 10, maxLength: 10),
        Country(id: "US", code: "US", name: "United States", dialCode: "+1", flag: "\u{1F1FA}\u{1F1F8}", minLength: 10, maxLength: 10),
        Country(id: "GB", code: "GB", name: "United Kingdom", dialCode: "+44", flag: "\u{1F1EC}\u{1F1E7}", minLength: 10, maxLength: 11),
        Country(id: "CA", code: "CA", name: "Canada", dialCode: "+1", flag: "\u{1F1E8}\u{1F1E6}", minLength: 10, maxLength: 10),
        Country(id: "AU", code: "AU", name: "Australia", dialCode: "+61", flag: "\u{1F1E6}\u{1F1FA}", minLength: 9, maxLength: 9),
        Country(id: "DE", code: "DE", name: "Germany", dialCode: "+49", flag: "\u{1F1E9}\u{1F1EA}", minLength: 10, maxLength: 11),
        Country(id: "FR", code: "FR", name: "France", dialCode: "+33", flag: "\u{1F1EB}\u{1F1F7}", minLength: 9, maxLength: 9),
        Country(id: "JP", code: "JP", name: "Japan", dialCode: "+81", flag: "\u{1F1EF}\u{1F1F5}", minLength: 10, maxLength: 11),
        Country(id: "SG", code: "SG", name: "Singapore", dialCode: "+65", flag: "\u{1F1F8}\u{1F1EC}", minLength: 8, maxLength: 8),
        Country(id: "AE", code: "AE", name: "UAE", dialCode: "+971", flag: "\u{1F1E6}\u{1F1EA}", minLength: 9, maxLength: 9),
    ]
}

