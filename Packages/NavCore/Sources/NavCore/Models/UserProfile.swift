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

public struct ChatMessage: Identifiable, Equatable, Codable {
    public let id: String
    public let matchId: String
    public let senderId: Int
    public let receiverId: Int
    public var content: String
    public var createdAt: Date?
    public var status: MessageStatus

    public enum MessageStatus: String, Codable {
        case sending, sent, delivered, read
    }

    public init(id: String, matchId: String, senderId: Int, receiverId: Int,
                content: String, createdAt: Date? = nil, status: MessageStatus = .sending) {
        self.id = id; self.matchId = matchId; self.senderId = senderId; self.receiverId = receiverId
        self.content = content; self.createdAt = createdAt; self.status = status
    }

}

public struct LikedProfile: Identifiable, Codable {
    public let id: String
    public var name: String
    public var age: Int
    public var photo: String
    public var type: LikeType
    public var likedAt: String
    public var message: String?

    public enum LikeType: String, Codable {
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
    // MARK: - Full country list (sorted alphabetically)
    static let all: [Country] = [
        Country(id: "AF", code: "AF", name: "Afghanistan", dialCode: "+93", flag: "\u{1F1E6}\u{1F1EB}", minLength: 9, maxLength: 9),
        Country(id: "AL", code: "AL", name: "Albania", dialCode: "+355", flag: "\u{1F1E6}\u{1F1F1}", minLength: 9, maxLength: 9),
        Country(id: "DZ", code: "DZ", name: "Algeria", dialCode: "+213", flag: "\u{1F1E9}\u{1F1FF}", minLength: 9, maxLength: 9),
        Country(id: "AR", code: "AR", name: "Argentina", dialCode: "+54", flag: "\u{1F1E6}\u{1F1F7}", minLength: 10, maxLength: 11),
        Country(id: "AM", code: "AM", name: "Armenia", dialCode: "+374", flag: "\u{1F1E6}\u{1F1F2}", minLength: 8, maxLength: 8),
        Country(id: "AU", code: "AU", name: "Australia", dialCode: "+61", flag: "\u{1F1E6}\u{1F1FA}", minLength: 9, maxLength: 9),
        Country(id: "AT", code: "AT", name: "Austria", dialCode: "+43", flag: "\u{1F1E6}\u{1F1F9}", minLength: 10, maxLength: 11),
        Country(id: "AZ", code: "AZ", name: "Azerbaijan", dialCode: "+994", flag: "\u{1F1E6}\u{1F1FF}", minLength: 9, maxLength: 9),
        Country(id: "BH", code: "BH", name: "Bahrain", dialCode: "+973", flag: "\u{1F1E7}\u{1F1ED}", minLength: 8, maxLength: 8),
        Country(id: "BD", code: "BD", name: "Bangladesh", dialCode: "+880", flag: "\u{1F1E7}\u{1F1E9}", minLength: 10, maxLength: 10),
        Country(id: "BY", code: "BY", name: "Belarus", dialCode: "+375", flag: "\u{1F1E7}\u{1F1FE}", minLength: 9, maxLength: 10),
        Country(id: "BE", code: "BE", name: "Belgium", dialCode: "+32", flag: "\u{1F1E7}\u{1F1EA}", minLength: 9, maxLength: 10),
        Country(id: "BO", code: "BO", name: "Bolivia", dialCode: "+591", flag: "\u{1F1E7}\u{1F1F4}", minLength: 8, maxLength: 8),
        Country(id: "BR", code: "BR", name: "Brazil", dialCode: "+55", flag: "\u{1F1E7}\u{1F1F7}", minLength: 10, maxLength: 11),
        Country(id: "BN", code: "BN", name: "Brunei", dialCode: "+673", flag: "\u{1F1E7}\u{1F1F3}", minLength: 7, maxLength: 7),
        Country(id: "BG", code: "BG", name: "Bulgaria", dialCode: "+359", flag: "\u{1F1E7}\u{1F1EC}", minLength: 9, maxLength: 9),
        Country(id: "KH", code: "KH", name: "Cambodia", dialCode: "+855", flag: "\u{1F1F0}\u{1F1ED}", minLength: 8, maxLength: 9),
        Country(id: "CA", code: "CA", name: "Canada", dialCode: "+1", flag: "\u{1F1E8}\u{1F1E6}", minLength: 10, maxLength: 10),
        Country(id: "CL", code: "CL", name: "Chile", dialCode: "+56", flag: "\u{1F1E8}\u{1F1F1}", minLength: 9, maxLength: 9),
        Country(id: "CN", code: "CN", name: "China", dialCode: "+86", flag: "\u{1F1E8}\u{1F1F3}", minLength: 11, maxLength: 11),
        Country(id: "CO", code: "CO", name: "Colombia", dialCode: "+57", flag: "\u{1F1E8}\u{1F1F4}", minLength: 10, maxLength: 10),
        Country(id: "CR", code: "CR", name: "Costa Rica", dialCode: "+506", flag: "\u{1F1E8}\u{1F1F7}", minLength: 8, maxLength: 8),
        Country(id: "HR", code: "HR", name: "Croatia", dialCode: "+385", flag: "\u{1F1ED}\u{1F1F7}", minLength: 9, maxLength: 9),
        Country(id: "CU", code: "CU", name: "Cuba", dialCode: "+53", flag: "\u{1F1E8}\u{1F1FA}", minLength: 8, maxLength: 8),
        Country(id: "CY", code: "CY", name: "Cyprus", dialCode: "+357", flag: "\u{1F1E8}\u{1F1FE}", minLength: 8, maxLength: 8),
        Country(id: "CZ", code: "CZ", name: "Czech Republic", dialCode: "+420", flag: "\u{1F1E8}\u{1F1FF}", minLength: 9, maxLength: 9),
        Country(id: "DK", code: "DK", name: "Denmark", dialCode: "+45", flag: "\u{1F1E9}\u{1F1F0}", minLength: 8, maxLength: 8),
        Country(id: "EC", code: "EC", name: "Ecuador", dialCode: "+593", flag: "\u{1F1EA}\u{1F1E8}", minLength: 9, maxLength: 9),
        Country(id: "EG", code: "EG", name: "Egypt", dialCode: "+20", flag: "\u{1F1EA}\u{1F1EC}", minLength: 10, maxLength: 10),
        Country(id: "EE", code: "EE", name: "Estonia", dialCode: "+372", flag: "\u{1F1EA}\u{1F1EA}", minLength: 7, maxLength: 8),
        Country(id: "ET", code: "ET", name: "Ethiopia", dialCode: "+251", flag: "\u{1F1EA}\u{1F1F9}", minLength: 9, maxLength: 9),
        Country(id: "FI", code: "FI", name: "Finland", dialCode: "+358", flag: "\u{1F1EB}\u{1F1EE}", minLength: 9, maxLength: 10),
        Country(id: "FR", code: "FR", name: "France", dialCode: "+33", flag: "\u{1F1EB}\u{1F1F7}", minLength: 9, maxLength: 9),
        Country(id: "GE", code: "GE", name: "Georgia", dialCode: "+995", flag: "\u{1F1EC}\u{1F1EA}", minLength: 9, maxLength: 9),
        Country(id: "DE", code: "DE", name: "Germany", dialCode: "+49", flag: "\u{1F1E9}\u{1F1EA}", minLength: 10, maxLength: 11),
        Country(id: "GH", code: "GH", name: "Ghana", dialCode: "+233", flag: "\u{1F1EC}\u{1F1ED}", minLength: 9, maxLength: 10),
        Country(id: "GR", code: "GR", name: "Greece", dialCode: "+30", flag: "\u{1F1EC}\u{1F1F7}", minLength: 10, maxLength: 10),
        Country(id: "HK", code: "HK", name: "Hong Kong", dialCode: "+852", flag: "\u{1F1ED}\u{1F1F0}", minLength: 8, maxLength: 8),
        Country(id: "HU", code: "HU", name: "Hungary", dialCode: "+36", flag: "\u{1F1ED}\u{1F1FA}", minLength: 9, maxLength: 9),
        Country(id: "IS", code: "IS", name: "Iceland", dialCode: "+354", flag: "\u{1F1EE}\u{1F1F8}", minLength: 7, maxLength: 7),
        Country(id: "IN", code: "IN", name: "India", dialCode: "+91", flag: "\u{1F1EE}\u{1F1F3}", minLength: 10, maxLength: 10),
        Country(id: "ID", code: "ID", name: "Indonesia", dialCode: "+62", flag: "\u{1F1EE}\u{1F1E9}", minLength: 10, maxLength: 12),
        Country(id: "IR", code: "IR", name: "Iran", dialCode: "+98", flag: "\u{1F1EE}\u{1F1F7}", minLength: 10, maxLength: 10),
        Country(id: "IQ", code: "IQ", name: "Iraq", dialCode: "+964", flag: "\u{1F1EE}\u{1F1F6}", minLength: 10, maxLength: 10),
        Country(id: "IE", code: "IE", name: "Ireland", dialCode: "+353", flag: "\u{1F1EE}\u{1F1EA}", minLength: 9, maxLength: 9),
        Country(id: "IL", code: "IL", name: "Israel", dialCode: "+972", flag: "\u{1F1EE}\u{1F1F1}", minLength: 9, maxLength: 10),
        Country(id: "IT", code: "IT", name: "Italy", dialCode: "+39", flag: "\u{1F1EE}\u{1F1F9}", minLength: 9, maxLength: 10),
        Country(id: "JM", code: "JM", name: "Jamaica", dialCode: "+1876", flag: "\u{1F1EF}\u{1F1F2}", minLength: 7, maxLength: 7),
        Country(id: "JP", code: "JP", name: "Japan", dialCode: "+81", flag: "\u{1F1EF}\u{1F1F5}", minLength: 10, maxLength: 11),
        Country(id: "JO", code: "JO", name: "Jordan", dialCode: "+962", flag: "\u{1F1EF}\u{1F1F4}", minLength: 9, maxLength: 9),
        Country(id: "KZ", code: "KZ", name: "Kazakhstan", dialCode: "+7", flag: "\u{1F1F0}\u{1F1FF}", minLength: 10, maxLength: 10),
        Country(id: "KE", code: "KE", name: "Kenya", dialCode: "+254", flag: "\u{1F1F0}\u{1F1EA}", minLength: 9, maxLength: 10),
        Country(id: "KW", code: "KW", name: "Kuwait", dialCode: "+965", flag: "\u{1F1F0}\u{1F1FC}", minLength: 8, maxLength: 8),
        Country(id: "KG", code: "KG", name: "Kyrgyzstan", dialCode: "+996", flag: "\u{1F1F0}\u{1F1EC}", minLength: 9, maxLength: 9),
        Country(id: "LV", code: "LV", name: "Latvia", dialCode: "+371", flag: "\u{1F1F1}\u{1F1FB}", minLength: 8, maxLength: 8),
        Country(id: "LB", code: "LB", name: "Lebanon", dialCode: "+961", flag: "\u{1F1F1}\u{1F1E7}", minLength: 7, maxLength: 8),
        Country(id: "LY", code: "LY", name: "Libya", dialCode: "+218", flag: "\u{1F1F1}\u{1F1FE}", minLength: 9, maxLength: 10),
        Country(id: "LT", code: "LT", name: "Lithuania", dialCode: "+370", flag: "\u{1F1F1}\u{1F1F9}", minLength: 8, maxLength: 8),
        Country(id: "LU", code: "LU", name: "Luxembourg", dialCode: "+352", flag: "\u{1F1F1}\u{1F1FA}", minLength: 9, maxLength: 9),
        Country(id: "MO", code: "MO", name: "Macau", dialCode: "+853", flag: "\u{1F1F2}\u{1F1F4}", minLength: 8, maxLength: 8),
        Country(id: "MY", code: "MY", name: "Malaysia", dialCode: "+60", flag: "\u{1F1F2}\u{1F1FE}", minLength: 9, maxLength: 10),
        Country(id: "MV", code: "MV", name: "Maldives", dialCode: "+960", flag: "\u{1F1F2}\u{1F1FB}", minLength: 7, maxLength: 7),
        Country(id: "MX", code: "MX", name: "Mexico", dialCode: "+52", flag: "\u{1F1F2}\u{1F1FD}", minLength: 10, maxLength: 10),
        Country(id: "MD", code: "MD", name: "Moldova", dialCode: "+373", flag: "\u{1F1F2}\u{1F1E9}", minLength: 8, maxLength: 8),
        Country(id: "MN", code: "MN", name: "Mongolia", dialCode: "+976", flag: "\u{1F1F2}\u{1F1F3}", minLength: 8, maxLength: 8),
        Country(id: "MA", code: "MA", name: "Morocco", dialCode: "+212", flag: "\u{1F1F2}\u{1F1E6}", minLength: 9, maxLength: 9),
        Country(id: "MM", code: "MM", name: "Myanmar", dialCode: "+95", flag: "\u{1F1F2}\u{1F1F2}", minLength: 8, maxLength: 10),
        Country(id: "NP", code: "NP", name: "Nepal", dialCode: "+977", flag: "\u{1F1F3}\u{1F1F5}", minLength: 10, maxLength: 10),
        Country(id: "NL", code: "NL", name: "Netherlands", dialCode: "+31", flag: "\u{1F1F3}\u{1F1F1}", minLength: 9, maxLength: 9),
        Country(id: "NZ", code: "NZ", name: "New Zealand", dialCode: "+64", flag: "\u{1F1F3}\u{1F1FF}", minLength: 8, maxLength: 10),
        Country(id: "NG", code: "NG", name: "Nigeria", dialCode: "+234", flag: "\u{1F1F3}\u{1F1EC}", minLength: 10, maxLength: 11),
        Country(id: "NO", code: "NO", name: "Norway", dialCode: "+47", flag: "\u{1F1F3}\u{1F1F4}", minLength: 8, maxLength: 8),
        Country(id: "OM", code: "OM", name: "Oman", dialCode: "+968", flag: "\u{1F1F4}\u{1F1F2}", minLength: 8, maxLength: 8),
        Country(id: "PK", code: "PK", name: "Pakistan", dialCode: "+92", flag: "\u{1F1F5}\u{1F1F0}", minLength: 10, maxLength: 10),
        Country(id: "PA", code: "PA", name: "Panama", dialCode: "+507", flag: "\u{1F1F5}\u{1F1E6}", minLength: 7, maxLength: 8),
        Country(id: "PE", code: "PE", name: "Peru", dialCode: "+51", flag: "\u{1F1F5}\u{1F1EA}", minLength: 9, maxLength: 9),
        Country(id: "PH", code: "PH", name: "Philippines", dialCode: "+63", flag: "\u{1F1F5}\u{1F1ED}", minLength: 10, maxLength: 10),
        Country(id: "PL", code: "PL", name: "Poland", dialCode: "+48", flag: "\u{1F1F5}\u{1F1F1}", minLength: 9, maxLength: 9),
        Country(id: "PT", code: "PT", name: "Portugal", dialCode: "+351", flag: "\u{1F1F5}\u{1F1F9}", minLength: 9, maxLength: 9),
        Country(id: "QA", code: "QA", name: "Qatar", dialCode: "+974", flag: "\u{1F1F6}\u{1F1E6}", minLength: 8, maxLength: 8),
        Country(id: "RO", code: "RO", name: "Romania", dialCode: "+40", flag: "\u{1F1F7}\u{1F1F4}", minLength: 9, maxLength: 10),
        Country(id: "RU", code: "RU", name: "Russia", dialCode: "+7", flag: "\u{1F1F7}\u{1F1FA}", minLength: 10, maxLength: 10),
        Country(id: "SA", code: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "\u{1F1F8}\u{1F1E6}", minLength: 9, maxLength: 9),
        Country(id: "RS", code: "RS", name: "Serbia", dialCode: "+381", flag: "\u{1F1F7}\u{1F1F8}", minLength: 9, maxLength: 10),
        Country(id: "SG", code: "SG", name: "Singapore", dialCode: "+65", flag: "\u{1F1F8}\u{1F1EC}", minLength: 8, maxLength: 8),
        Country(id: "SK", code: "SK", name: "Slovakia", dialCode: "+421", flag: "\u{1F1F8}\u{1F1F0}", minLength: 9, maxLength: 9),
        Country(id: "SI", code: "SI", name: "Slovenia", dialCode: "+386", flag: "\u{1F1F8}\u{1F1EE}", minLength: 8, maxLength: 8),
        Country(id: "ZA", code: "ZA", name: "South Africa", dialCode: "+27", flag: "\u{1F1FF}\u{1F1E6}", minLength: 9, maxLength: 9),
        Country(id: "KR", code: "KR", name: "South Korea", dialCode: "+82", flag: "\u{1F1F0}\u{1F1F7}", minLength: 10, maxLength: 11),
        Country(id: "ES", code: "ES", name: "Spain", dialCode: "+34", flag: "\u{1F1EA}\u{1F1F8}", minLength: 9, maxLength: 9),
        Country(id: "LK", code: "LK", name: "Sri Lanka", dialCode: "+94", flag: "\u{1F1F1}\u{1F1F0}", minLength: 9, maxLength: 9),
        Country(id: "SE", code: "SE", name: "Sweden", dialCode: "+46", flag: "\u{1F1F8}\u{1F1EA}", minLength: 9, maxLength: 10),
        Country(id: "CH", code: "CH", name: "Switzerland", dialCode: "+41", flag: "\u{1F1E8}\u{1F1ED}", minLength: 9, maxLength: 9),
        Country(id: "TW", code: "TW", name: "Taiwan", dialCode: "+886", flag: "\u{1F1F9}\u{1F1FC}", minLength: 9, maxLength: 10),
        Country(id: "TZ", code: "TZ", name: "Tanzania", dialCode: "+255", flag: "\u{1F1F9}\u{1F1FF}", minLength: 9, maxLength: 9),
        Country(id: "TH", code: "TH", name: "Thailand", dialCode: "+66", flag: "\u{1F1F9}\u{1F1ED}", minLength: 9, maxLength: 9),
        Country(id: "TR", code: "TR", name: "Turkey", dialCode: "+90", flag: "\u{1F1F9}\u{1F1F7}", minLength: 10, maxLength: 10),
        Country(id: "UA", code: "UA", name: "Ukraine", dialCode: "+380", flag: "\u{1F1FA}\u{1F1E6}", minLength: 9, maxLength: 9),
        Country(id: "AE", code: "AE", name: "UAE", dialCode: "+971", flag: "\u{1F1E6}\u{1F1EA}", minLength: 9, maxLength: 9),
        Country(id: "GB", code: "GB", name: "United Kingdom", dialCode: "+44", flag: "\u{1F1EC}\u{1F1E7}", minLength: 10, maxLength: 11),
        Country(id: "US", code: "US", name: "United States", dialCode: "+1", flag: "\u{1F1FA}\u{1F1F8}", minLength: 10, maxLength: 10),
        Country(id: "UY", code: "UY", name: "Uruguay", dialCode: "+598", flag: "\u{1F1FA}\u{1F1FE}", minLength: 8, maxLength: 8),
        Country(id: "UZ", code: "UZ", name: "Uzbekistan", dialCode: "+998", flag: "\u{1F1FA}\u{1F1FF}", minLength: 9, maxLength: 9),
        Country(id: "VE", code: "VE", name: "Venezuela", dialCode: "+58", flag: "\u{1F1FB}\u{1F1EA}", minLength: 10, maxLength: 10),
        Country(id: "VN", code: "VN", name: "Vietnam", dialCode: "+84", flag: "\u{1F1FB}\u{1F1F3}", minLength: 9, maxLength: 10),
        Country(id: "ZM", code: "ZM", name: "Zambia", dialCode: "+260", flag: "\u{1F1FF}\u{1F1F2}", minLength: 9, maxLength: 9),
        Country(id: "ZW", code: "ZW", name: "Zimbabwe", dialCode: "+263", flag: "\u{1F1FF}\u{1F1FC}", minLength: 9, maxLength: 9),
    ]

    /// Returns the country matching the device's current locale/region,
    /// falling back to United States if no match is found.
    static var deviceDefault: Country {
        let regionCode: String? = {
            // 1. Prefer the device's current region setting (most reliable)
            if let region = Locale.current.region?.identifier {
                return region
            }
            // 2. Legacy fallback
            return Locale.current.language.region?.identifier
        }()

        if let code = regionCode,
           let match = all.first(where: { $0.code == code }) {
            return match
        }
        // Fallback to US
        return all.first(where: { $0.code == "US" }) ?? all[0]
    }
}

