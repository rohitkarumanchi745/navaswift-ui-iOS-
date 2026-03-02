import Foundation
import SwiftUI

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    var name: String?
    var phoneNumber: String?
    var dob: String?
    var age: Int?
    var gender: String?
    var bio: String?
    var location: String?
    var profession: String?
    var professionCategory: String?
    var professionTitle: String?
    var interests: [String]?
    var photos: [String]?
    var isProfileComplete: Bool?
    var isVerified: Bool?
    var isStudentVerified: Bool?
    var heightCm: Int?
    var languages: [String]?
    var lookingFor: String?
    var voiceIntroUrl: String?

    var displayName: String {
        name ?? "User"
    }

    var firstName: String {
        name?.components(separatedBy: " ").first ?? "User"
    }

    var primaryPhoto: String? {
        photos?.first
    }

    var profileCompletion: Int {
        let sections: [Any?] = [name, dob, bio, photos?.isEmpty == false ? photos : nil]
        let completed = sections.compactMap { $0 }.count
        return min(100, Int((Double(completed) / Double(sections.count)) * 100))
    }
}

struct DiscoverProfile: Identifiable, Equatable {
    let id: String
    var name: String?
    var age: Int?
    var location: String?
    var profession: String?
    var compatibilityScore: Int?
    var bio: String?
    var interests: [String]?
    var photos: [String]?
    var isVerified: Bool
    var voiceIntroUrl: String?
    var hasVoiceIntro: Bool
    var hasReels: Bool
    var languages: [String]?

    var primaryPhoto: String? {
        photos?.first
    }

    static func == (lhs: DiscoverProfile, rhs: DiscoverProfile) -> Bool {
        lhs.id == rhs.id
    }
}

struct MatchProfile: Identifiable {
    let id: String
    let matchId: String
    var name: String
    var age: Int
    var photo: String
    var lastMessage: String?
    var timestamp: String?
    var unreadCount: Int
    var isOnline: Bool
    var isMutual: Bool
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let matchId: String
    let senderId: Int
    let receiverId: Int
    var content: String
    var createdAt: Date?
    var status: MessageStatus

    enum MessageStatus: String {
        case sending, sent, delivered, read
    }
}

struct LikedProfile: Identifiable {
    let id: String
    var name: String
    var age: Int
    var photo: String
    var type: LikeType
    var likedAt: String

    enum LikeType: String {
        case swipe, reel
    }
}

// MARK: - Country Model
struct Country: Identifiable, Equatable {
    let id: String  // code
    let code: String
    let name: String
    let dialCode: String
    let flag: String
    let minLength: Int
    let maxLength: Int
}

// MARK: - Premium Tier (bridges UI config to StoreKit product IDs)
enum PremiumTier: String, CaseIterable, Identifiable {
    case gold, platinum, ultra
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .ultra: return "Ultra"
        }
    }
    
    var storeProductID: String {
        switch self {
        case .gold: return StoreProductID.goldMonthly.rawValue
        case .platinum: return StoreProductID.platinumMonthly.rawValue
        case .ultra: return StoreProductID.ultraMonthly.rawValue
        }
    }
    
    var icon: String {
        switch self {
        case .gold: return "star.fill"
        case .platinum: return "crown.fill"
        case .ultra: return "diamond.fill"
        }
    }
    
    var badge: String? {
        switch self {
        case .platinum: return "POPULAR"
        case .ultra: return "BEST VALUE"
        default: return nil
        }
    }
    
    var accentColor: Color {
        switch self {
        case .gold: return Color(hex: "D4AF37")
        case .platinum: return Color(hex: "845EC2")
        case .ultra: return Color(hex: "4ECDC4")
        }
    }
    
    var features: [String] {
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
extension DiscoverProfile {
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

extension Country {
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

extension MatchProfile {
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

extension LikedProfile {
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


