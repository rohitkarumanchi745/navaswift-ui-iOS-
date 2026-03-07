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
    public var heightCm: Int?
    public var languages: [String]?
    public var lookingFor: String?
    public var voiceIntroUrl: String?

    public init(id: String, name: String? = nil, phoneNumber: String? = nil, dob: String? = nil,
                age: Int? = nil, gender: String? = nil, bio: String? = nil, location: String? = nil,
                profession: String? = nil, professionCategory: String? = nil, professionTitle: String? = nil,
                interests: [String]? = nil, photos: [String]? = nil, isProfileComplete: Bool? = nil,
                isVerified: Bool? = nil, isStudentVerified: Bool? = nil, heightCm: Int? = nil,
                languages: [String]? = nil, lookingFor: String? = nil, voiceIntroUrl: String? = nil) {
        self.id = id; self.name = name; self.phoneNumber = phoneNumber; self.dob = dob
        self.age = age; self.gender = gender; self.bio = bio; self.location = location
        self.profession = profession; self.professionCategory = professionCategory
        self.professionTitle = professionTitle; self.interests = interests; self.photos = photos
        self.isProfileComplete = isProfileComplete; self.isVerified = isVerified
        self.isStudentVerified = isStudentVerified; self.heightCm = heightCm
        self.languages = languages; self.lookingFor = lookingFor; self.voiceIntroUrl = voiceIntroUrl
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

public struct DiscoverProfile: Identifiable, Equatable {
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
    public var voiceIntroUrl: String?
    public var hasVoiceIntro: Bool
    public var hasReels: Bool
    public var languages: [String]?

    public var primaryPhoto: String? { photos?.first }

    public init(id: String, name: String? = nil, age: Int? = nil, location: String? = nil,
                profession: String? = nil, compatibilityScore: Int? = nil, bio: String? = nil,
                interests: [String]? = nil, photos: [String]? = nil, isVerified: Bool = false,
                voiceIntroUrl: String? = nil, hasVoiceIntro: Bool = false, hasReels: Bool = false,
                languages: [String]? = nil) {
        self.id = id; self.name = name; self.age = age; self.location = location
        self.profession = profession; self.compatibilityScore = compatibilityScore; self.bio = bio
        self.interests = interests; self.photos = photos; self.isVerified = isVerified
        self.voiceIntroUrl = voiceIntroUrl; self.hasVoiceIntro = hasVoiceIntro
        self.hasReels = hasReels; self.languages = languages
    }

    public static func == (lhs: DiscoverProfile, rhs: DiscoverProfile) -> Bool {
        lhs.id == rhs.id
    }
}

public struct MatchProfile: Identifiable {
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
}

public struct LikedProfile: Identifiable {
    public let id: String
    public var name: String
    public var age: Int
    public var photo: String
    public var type: LikeType
    public var likedAt: String

    public enum LikeType: String {
        case swipe, reel
    }

    public init(id: String, name: String, age: Int, photo: String, type: LikeType, likedAt: String) {
        self.id = id; self.name = name; self.age = age; self.photo = photo
        self.type = type; self.likedAt = likedAt
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
        DiscoverProfile(
            id: "demo-1", name: "Priya", age: 26, location: "Hyderabad",
            profession: "Product Designer", compatibilityScore: 94,
            bio: "Voice artist, veena player, and filter coffee enthusiast. Looking for someone to explore life with.",
            interests: ["Music", "Art", "Coffee", "Travel", "Yoga"],
            photos: ["https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=800&q=80"],
            isVerified: true, hasVoiceIntro: true, hasReels: true,
            languages: ["Telugu", "English", "Hindi"]
        ),
        DiscoverProfile(
            id: "demo-2", name: "Arjun", age: 29, location: "Bangalore",
            profession: "Software Engineer", compatibilityScore: 91,
            bio: "Building apps by day, exploring trails by weekend. Dog dad to a golden retriever.",
            interests: ["Hiking", "Tech", "Photography", "Dogs"],
            photos: ["https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80"],
            isVerified: true, hasVoiceIntro: true, hasReels: false,
            languages: ["Telugu", "English"]
        ),
        DiscoverProfile(
            id: "demo-3", name: "Meera", age: 27, location: "Chennai",
            profession: "Marketing Manager", compatibilityScore: 88,
            bio: "Beach lover, book nerd, and amateur chef. Weekend warrior.",
            interests: ["Reading", "Cooking", "Beach", "Movies"],
            photos: ["https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=800&q=80"],
            isVerified: false, hasVoiceIntro: false, hasReels: true,
            languages: ["Telugu", "Tamil", "English"]
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
        MatchProfile(id: "m1", matchId: "match1", name: "Priya", age: 24,
                     photo: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
                     lastMessage: "Hey! How are you?", timestamp: "2m", unreadCount: 2, isOnline: true, isMutual: true),
        MatchProfile(id: "m2", matchId: "match2", name: "Sneha", age: 26,
                     photo: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
                     lastMessage: "That sounds great!", timestamp: "1h", unreadCount: 0, isOnline: false, isMutual: true),
        MatchProfile(id: "m3", matchId: "match3", name: "Meera", age: 25,
                     photo: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400",
                     lastMessage: "See you soon!", timestamp: "3h", unreadCount: 1, isOnline: true, isMutual: true),
    ]
}

public extension LikedProfile {
    static let demos: [LikedProfile] = [
        LikedProfile(id: "ls1", name: "Priya", age: 24,
                     photo: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
                     type: .swipe, likedAt: "2h"),
        LikedProfile(id: "ls2", name: "Sneha", age: 26,
                     photo: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400",
                     type: .swipe, likedAt: "5h"),
        LikedProfile(id: "ls3", name: "Ananya", age: 23,
                     photo: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400",
                     type: .swipe, likedAt: "1d"),
    ]
}
