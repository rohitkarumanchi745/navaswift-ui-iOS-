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

    public init(id: String, matchId: String, name: String, age: Int, photo: String,
                lastMessage: String? = nil, timestamp: String? = nil, unreadCount: Int = 0,
                isOnline: Bool = false, isMutual: Bool = false) {
        self.id = id; self.matchId = matchId; self.name = name; self.age = age; self.photo = photo
        self.lastMessage = lastMessage; self.timestamp = timestamp; self.unreadCount = unreadCount
        self.isOnline = isOnline; self.isMutual = isMutual
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

    public static func demoConversation(matchId: String, meId: Int, partnerId: Int, partnerName: String) -> [ChatMessage] {
        let now = Date()
        let msgs: [(String, Bool, TimeInterval)] = [
            ("Hey \(partnerName)! Loved your bio — veena player and coffee lover? That's a rare combo", true, -7200),
            ("Haha yes! Filter coffee is basically my personality at this point", false, -7100),
            ("I feel that. I'm more of a chai person though, hope that's not a dealbreaker", true, -6800),
            ("Hmm... I'll allow it if you can handle spicy food", false, -6600),
            ("I'm from Hyderabad, spice is in my blood", true, -6400),
            ("Okay you passed the test. What do you do when you're not swiping?", false, -6000),
            ("I work in tech but honestly I spend most of my free time on photography", true, -5500),
            ("No way! I saw some of your pics, the one from Goa was stunning", false, -5200),
            ("Thanks! That was from last monsoon. The rain made everything so dramatic", true, -4800),
            ("I love Goa in monsoon! Most people only go in winter", false, -4400),
            ("Right? It's so underrated. The waterfalls are incredible that time of year", true, -3800),
            ("We should plan a trip sometime. I know this hidden beach near Palolem", false, -3200),
            ("Now you have my attention. When are you free?", true, -2400),
            ("This weekend works! Let me send you the location", false, -1800),
            ("Perfect, looking forward to it!", true, -600),
            ("Same here! See you Saturday", false, -300),
        ]
        return msgs.enumerated().map { i, m in
            ChatMessage(
                id: "demo-msg-\(i)",
                matchId: matchId,
                senderId: m.1 ? meId : partnerId,
                receiverId: m.1 ? partnerId : meId,
                content: m.0,
                createdAt: now.addingTimeInterval(m.2),
                status: i == msgs.count - 1 ? .delivered : .read
            )
        }
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

// MARK: - Demo Data
public extension DiscoverProfile {
    static let demos: [DiscoverProfile] = [
        // 1. Priya — Product Designer, Hyderabad
        DiscoverProfile(
            id: "demo-1", name: "Priya", age: 26, location: "Hyderabad",
            profession: "Product Designer", compatibilityScore: 94,
            bio: "Voice artist, veena player, and filter coffee enthusiast. Looking for someone to explore life with. I believe great design can change the world — and great chai can change a Monday.",
            interests: ["Music", "Art", "Coffee", "Travel", "Yoga", "Design"],
            photos: [
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1502767089025-6572583495f9?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isAlumniVerified: true, graduationYear: 2022, university: "NID Hyderabad",
            hasVoiceIntro: true, hasReels: true,
            languages: ["Telugu", "English", "Hindi"]
        ),
        // 2. Arjun — Software Engineer, Bangalore
        DiscoverProfile(
            id: "demo-2", name: "Arjun", age: 29, location: "Bangalore",
            profession: "Software Engineer", compatibilityScore: 91,
            bio: "Building apps by day, exploring trails by weekend. Dog dad to a golden retriever named Toast. If you can keep up on a 10k run, I'm already interested.",
            interests: ["Hiking", "Tech", "Photography", "Dogs", "Running", "Startups"],
            photos: [
                "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isProfessionalVerified: true, isNewInTown: true,
            professionalOrg: "Bangalore Product Designers",
            hasVoiceIntro: true, hasReels: false,
            languages: ["Kannada", "English", "Hindi"]
        ),
        // 3. Meera — Marketing Manager, Chennai
        DiscoverProfile(
            id: "demo-3", name: "Meera", age: 27, location: "Chennai",
            profession: "Marketing Manager", compatibilityScore: 88,
            bio: "Beach lover, book nerd, and amateur chef. Weekend warrior who'd rather be at a farmer's market than a club. Looking for my partner in crime for road trips.",
            interests: ["Reading", "Cooking", "Beach", "Movies", "Gardening"],
            photos: [
                "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1496440737103-cd596325d314?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: false,
            isAlumniVerified: true, graduationYear: 2021, university: "IIT Madras",
            hasVoiceIntro: false, hasReels: true,
            languages: ["Tamil", "English", "Telugu"]
        ),
        // 4. Sneha — Fashion Stylist, Mumbai
        DiscoverProfile(
            id: "demo-4", name: "Sneha", age: 25, location: "Mumbai",
            profession: "Fashion Stylist", compatibilityScore: 85,
            bio: "Styling celebs by day, dancing salsa by night. Life's too short for boring outfits and bad coffee. If you can make me laugh, you're already ahead.",
            interests: ["Fashion", "Dance", "Photography", "Food", "Salsa"],
            photos: [
                "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isProfessionalVerified: true, professionalOrg: "Mumbai Fashion Network",
            hasVoiceIntro: false, hasReels: true,
            languages: ["Hindi", "English", "Marathi"]
        ),
        // 5. Kavya — Marine Biologist, Goa
        DiscoverProfile(
            id: "demo-5", name: "Kavya", age: 24, location: "Goa",
            profession: "Marine Biologist", compatibilityScore: 79,
            bio: "Scuba instructor on weekends. I study coral reefs and dream about saving the ocean. Looking for someone who appreciates sunsets and doesn't mind sandy toes.",
            interests: ["Scuba Diving", "Nature", "Sustainability", "Surfing", "Yoga"],
            photos: [
                "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1504703395950-b89145a5425b?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1506929562872-bb421503ef21?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isNewInTown: true,
            hasVoiceIntro: true, hasReels: true,
            languages: ["Konkani", "English", "Hindi"]
        ),
        // 6. Rohan — Data Scientist, Pune
        DiscoverProfile(
            id: "demo-6", name: "Rohan", age: 28, location: "Pune",
            profession: "Data Scientist", compatibilityScore: 82,
            bio: "PhD dropout turned startup founder. I build ML models and also build really good playlists. Currently training for my first marathon.",
            interests: ["Machine Learning", "Music", "Running", "Chess", "Cooking"],
            photos: [
                "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1480455624313-e29b44bbfde1?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1522529599102-193c0d76b5b6?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1552374196-c4e7ffc6e126?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isAlumniVerified: true, isProfessionalVerified: true,
            graduationYear: 2020, university: "IIT Bombay",
            professionalOrg: "Pune AI/ML Meetup",
            hasVoiceIntro: false, hasReels: false,
            languages: ["Hindi", "English", "Marathi"]
        ),
        // 7. Ananya — Architecture Student, Delhi
        DiscoverProfile(
            id: "demo-7", name: "Ananya", age: 23, location: "Delhi",
            profession: "Architecture Student", compatibilityScore: 76,
            bio: "Final year at SPA Delhi. I sketch buildings for fun and bake sourdough when stressed. Always up for exploring old parts of the city on foot.",
            interests: ["Architecture", "Baking", "Sketching", "History", "Walking"],
            photos: [
                "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1485893086445-ed75865251e0?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: false, graduationYear: 2027, university: "SPA Delhi",
            hasVoiceIntro: false, hasReels: true,
            languages: ["Hindi", "English", "Punjabi"]
        ),
        // 8. Vikram — Orthopedic Surgeon, Hyderabad
        DiscoverProfile(
            id: "demo-8", name: "Vikram", age: 30, location: "Hyderabad",
            profession: "Orthopedic Surgeon", compatibilityScore: 90,
            bio: "Doctor by profession, drummer by passion. I fix bones and break beats. Looking for someone who can handle my terrible puns and spontaneous travel plans.",
            interests: ["Music", "Drums", "Fitness", "Travel", "Stand-up Comedy"],
            photos: [
                "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1463453091185-61582044d556?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1548372290-8d01b6c8e78c?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1504257432389-52343af06ae3?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isAlumniVerified: true, isProfessionalVerified: true,
            graduationYear: 2019, university: "AIIMS Delhi",
            professionalOrg: "Indian Medical Association",
            hasVoiceIntro: true, hasReels: true,
            languages: ["Telugu", "English", "Hindi"]
        ),
        // 9. Diya — Documentary Filmmaker, Kolkata
        DiscoverProfile(
            id: "demo-9", name: "Diya", age: 26, location: "Kolkata",
            profession: "Documentary Filmmaker", compatibilityScore: 73,
            bio: "Telling stories one frame at a time. Obsessed with street food, old cinema, and finding magic in everyday moments. Chai > coffee, fight me.",
            interests: ["Filmmaking", "Photography", "Street Food", "Cinema", "Writing"],
            photos: [
                "https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1499887142886-791eca5918cd?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1464863979621-258859e62245?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1502767089025-6572583495f9?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isAlumniVerified: true, isNewInTown: true,
            graduationYear: 2022, university: "FTII Pune",
            hasVoiceIntro: false, hasReels: true,
            languages: ["Bengali", "English", "Hindi"]
        ),
        // 10. Aditya — Navy Officer, Vizag
        DiscoverProfile(
            id: "demo-10", name: "Aditya", age: 27, location: "Vizag",
            profession: "Navy Officer", compatibilityScore: 87,
            bio: "Submariner who surfaces for good food and better company. I can cook a mean biryani and navigate by the stars. Adventure is my middle name — literally.",
            interests: ["Sailing", "Cooking", "Astronomy", "Fitness", "Photography"],
            photos: [
                "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1474176857210-7287d38d27c6?auto=format&fit=crop&w=800&q=80",
                "https://images.unsplash.com/photo-1519345182560-3f2917c472ef?auto=format&fit=crop&w=800&q=80"
            ],
            isVerified: true,
            isAlumniVerified: true, isProfessionalVerified: true, isNewInTown: true,
            graduationYear: 2020, university: "Indian Naval Academy",
            professionalOrg: "Indian Navy Officers' Club",
            hasVoiceIntro: true, hasReels: false,
            languages: ["Telugu", "English"]
        ),
    ]
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

public extension MatchProfile {
    static let demos: [MatchProfile] = [
        MatchProfile(id: "m1", matchId: "match1", name: "Priya", age: 26,
                     photo: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
                     lastMessage: "Hey! How are you?", timestamp: "2m", unreadCount: 2, isOnline: true, isMutual: true),
        MatchProfile(id: "m2", matchId: "match2", name: "Sneha", age: 25,
                     photo: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
                     lastMessage: "That sounds great!", timestamp: "1h", unreadCount: 0, isOnline: false, isMutual: true),
        MatchProfile(id: "m3", matchId: "match3", name: "Meera", age: 27,
                     photo: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400",
                     lastMessage: "See you soon!", timestamp: "3h", unreadCount: 1, isOnline: true, isMutual: true),
        MatchProfile(id: "m4", matchId: "match4", name: "Kavya", age: 24,
                     photo: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400",
                     lastMessage: "That sunset photo was gorgeous!", timestamp: "5h", unreadCount: 0, isOnline: true, isMutual: true),
        MatchProfile(id: "m5", matchId: "match5", name: "Ananya", age: 23,
                     photo: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
                     lastMessage: "Haha you're so funny", timestamp: "1d", unreadCount: 3, isOnline: false, isMutual: true),
        MatchProfile(id: "m6", matchId: "match6", name: "Diya", age: 26,
                     photo: "https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?w=400",
                     lastMessage: nil, timestamp: nil, unreadCount: 0, isOnline: true, isMutual: true),
        MatchProfile(id: "m7", matchId: "match7", name: "Arjun", age: 29,
                     photo: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
                     lastMessage: "Let's grab coffee this weekend?", timestamp: "2d", unreadCount: 0, isOnline: false, isMutual: true),
    ]
}

public extension LikedProfile {
    static let demos: [LikedProfile] = [
        LikedProfile(id: "ls1", name: "Priya", age: 26,
                     photo: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
                     type: .superLike, likedAt: "2h",
                     message: "Your travel photos are incredible! That Goa sunset was everything"),
        LikedProfile(id: "ls2", name: "Sneha", age: 25,
                     photo: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
                     type: .swipe, likedAt: "5h",
                     message: "Fellow chai lover! We need to find the best cutting chai in Mumbai together"),
        LikedProfile(id: "ls3", name: "Ananya", age: 23,
                     photo: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
                     type: .swipe, likedAt: "1d"),
        LikedProfile(id: "ls4", name: "Meera", age: 27,
                     photo: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400",
                     type: .superLike, likedAt: "3h",
                     message: "I saw you're into trail running too! What's your favorite route in the city?"),
        LikedProfile(id: "ls5", name: "Kavya", age: 24,
                     photo: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400",
                     type: .reel, likedAt: "6h"),
        LikedProfile(id: "ls6", name: "Diya", age: 26,
                     photo: "https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?w=400",
                     type: .swipe, likedAt: "8h"),
        LikedProfile(id: "ls7", name: "Rohan", age: 28,
                     photo: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
                     type: .superLike, likedAt: "1d"),
        LikedProfile(id: "ls8", name: "Vikram", age: 30,
                     photo: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400",
                     type: .swipe, likedAt: "2d",
                     message: "Your gym reel was motivating! What's your workout split?"),
    ]
}
