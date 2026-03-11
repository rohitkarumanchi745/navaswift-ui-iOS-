import Foundation

// MARK: - GraphQL Response Envelope

/// Generic wrapper for GraphQL JSON responses.
/// Parses `{ "data": { ... }, "errors": [...] }` with type-safe `data` field.
public struct GraphQLResponse<T: Decodable>: Decodable {
    public let data: T?
    public let errors: [GraphQLError]?
}

public struct GraphQLError: Decodable {
    public let message: String
    public let locations: [ErrorLocation]?
    public let path: [String]?

    public struct ErrorLocation: Decodable {
        public let line: Int
        public let column: Int
    }
}

// MARK: - Auth Responses

public struct SendOtpData: Decodable {
    public let sendOtp: SendOtpResult

    public struct SendOtpResult: Decodable {
        public let message: String?
        public let otp: String?
    }
}

public struct VerifyOtpData: Decodable {
    public let verifyOtp: VerifyOtpResult

    public struct VerifyOtpResult: Decodable {
        public let accessToken: String
        public let refreshToken: String?
        public let userId: FlexibleID?
        public let isNewUser: Bool?
        public let isProfileComplete: Bool?
    }
}

// MARK: - Token Refresh Response (REST)

public struct RefreshTokenResponse: Decodable {
    public let accessToken: String
    public let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

/// Handles IDs that may come as Int or String from the backend
public struct FlexibleID: Decodable, CustomStringConvertible {
    public let value: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = String(intVal)
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else {
            value = ""
        }
    }

    public var description: String { value }
}

// MARK: - Me / Profile Response

public struct MeData: Decodable {
    public let me: MeProfile?

    public struct MeProfile: Decodable {
        public let id: FlexibleID
        public let name: String?
        public let phoneNumber: String?
        public let age: Int?
        public let gender: String?
        public let bio: String?
        public let location: String?
        public let interests: [String]?
        public let languages: [String]?
        public let lookingFor: String?
        public let professionCategory: String?
        public let professionTitle: String?
        public let heightCm: Int?
        public let photos: [String]?
        public let isProfileComplete: FlexibleBool?
        public let isVerified: Bool?
        public let isStudentVerified: Bool?
        public let voiceIntroUrl: String?
    }
}

/// Handles booleans that may come as Bool, Int, or NSNumber from GraphQL
public struct FlexibleBool: Decodable {
    public let value: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal != 0
        } else {
            value = false
        }
    }
}

// MARK: - Discover Response

public struct DiscoverData: Decodable {
    public let discover: [DiscoverItem]?

    public struct DiscoverItem: Decodable {
        public let id: FlexibleID
        public let name: String?
        public let age: Int?
        public let bio: String?
        public let location: String?
        public let photos: [String]?
        public let interests: [String]?
        public let languages: [String]?
        public let compatibilityScore: Double?
        public let isVerified: Bool?
        public let professionTitle: String?
        public let voiceIntroUrl: String?
        public let hasVoiceIntro: Bool?
    }
}

// MARK: - Like/Pass Responses

public struct LikeUserData: Decodable {
    public let likeUser: LikeResult?

    public struct LikeResult: Decodable {
        public let success: Bool?
        public let isMutual: Bool?
        public let matchId: String?
    }
}

// MARK: - Matches Response

public struct MatchesData: Decodable {
    public let matches: [MatchItem]?

    public struct MatchItem: Decodable {
        public let id: FlexibleID
        public let partner: Partner?
        public let isMutual: Bool?
        public let matchedAt: String?

        public struct Partner: Decodable {
            public let id: FlexibleID
            public let name: String?
            public let age: Int?
            public let photos: [String]?
        }
    }
}

// MARK: - Conversation Response

public struct ConversationData: Decodable {
    public let conversation: [MessageItem]?

    public struct MessageItem: Decodable {
        public let id: FlexibleID
        public let matchId: String?
        public let senderId: Int?
        public let receiverId: Int?
        public let content: String?
        public let createdAt: String?
    }
}

public struct SendMessageData: Decodable {
    public let sendChatMessage: ConversationData.MessageItem?
}

// MARK: - Preferences Response

public struct PreferencesData: Decodable {
    public let myPreferences: Preferences?

    public struct Preferences: Decodable {
        public let minAge: Int?
        public let maxAge: Int?
        public let maxDistanceKm: Int?
        public let preferredGenders: [String]?
        public let preferredProfessions: [String]?
        public let onlyVerified: Bool?
    }
}

// MARK: - Sent Likes Response

public struct SentLikesData: Decodable {
    public let sentLikes: [SentLikeItem]?

    public struct SentLikeItem: Decodable {
        public let id: FlexibleID
        public let targetUser: TargetUser?
        public let likedAt: String?

        public struct TargetUser: Decodable {
            public let id: FlexibleID
            public let name: String?
            public let age: Int?
            public let photos: [String]?
        }
    }
}

// MARK: - User Profile Detail Response

public struct UserProfileData: Decodable {
    public let userProfile: DiscoverData.DiscoverItem?
}
