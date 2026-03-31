import Foundation

// MARK: - Spots

public struct Spot: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let userName: String
    public let userPhoto: String?
    public let content: String
    public let imageUrl: String?
    public let latitude: Double
    public let longitude: Double
    public let locality: String?
    public let createdAt: String
    public let expiresAt: String?
    public let reactCount: Int?
    public let messageCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, content, latitude, longitude, locality
        case userId = "user_id"
        case userName = "user_name"
        case userPhoto = "user_photo"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case reactCount = "react_count"
        case messageCount = "message_count"
    }
}

public struct SpotMessage: Decodable, Identifiable {
    public let id: String
    public let spotId: String
    public let senderId: String
    public let senderName: String
    public let senderPhoto: String?
    public let content: String
    public let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, content
        case spotId = "spot_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderPhoto = "sender_photo"
        case createdAt = "created_at"
    }
}

public struct SpotFeedResponse: Decodable {
    public let spots: [Spot]?
}

public struct SpotMessagesResponse: Decodable {
    public let messages: [SpotMessage]?
}

public struct SpotCreateResponse: Decodable {
    public let success: Bool?
    public let spot: Spot?
}

public struct SpotReactResponse: Decodable {
    public let success: Bool?
    public let reactCount: Int?

    private enum CodingKeys: String, CodingKey {
        case success
        case reactCount = "react_count"
    }
}

// MARK: - Playgrounds

public enum PlaygroundType: String, Codable, CaseIterable, Identifiable {
    case studyGroup = "study_group"
    case hangout
    case sports
    case gaming
    case music
    case food
    case travel
    case other

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = PlaygroundType(rawValue: raw) ?? .other
    }

    public var displayName: String {
        switch self {
        case .studyGroup: return "Study Group"
        case .hangout: return "Hangout"
        case .sports: return "Sports"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .food: return "Food"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    public var icon: String {
        switch self {
        case .studyGroup: return "book.fill"
        case .hangout: return "cup.and.saucer.fill"
        case .sports: return "sportscourt.fill"
        case .gaming: return "gamecontroller.fill"
        case .music: return "music.note"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

public struct Playground: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let type: PlaygroundType
    public let creatorId: String?
    public let creatorName: String?
    public let memberCount: Int
    public let maxMembers: Int?
    public let latitude: Double?
    public let longitude: Double?
    public let locality: String?
    public let isJoined: Bool
    public let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, type, latitude, longitude, locality
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case isJoined = "is_joined"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        type = try c.decodeIfPresent(PlaygroundType.self, forKey: .type) ?? .other
        creatorId = try c.decodeIfPresent(String.self, forKey: .creatorId)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        maxMembers = try c.decodeIfPresent(Int.self, forKey: .maxMembers)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        locality = try c.decodeIfPresent(String.self, forKey: .locality)
        isJoined = try c.decodeIfPresent(Bool.self, forKey: .isJoined) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

public struct PlaygroundMember: Decodable, Identifiable {
    public let id: String
    public let userId: String
    public let name: String
    public let photo: String?
    public let joinedAt: String

    private enum CodingKeys: String, CodingKey {
        case id, name, photo
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

public struct PlaygroundListResponse: Decodable {
    public let playgrounds: [Playground]?
}

public struct PlaygroundDetailResponse: Decodable {
    public let playground: Playground?
}

public struct PlaygroundMembersResponse: Decodable {
    public let members: [PlaygroundMember]?
}

public struct PlaygroundActionResponse: Decodable {
    public let success: Bool?
    public let message: String?
}

// MARK: - Events

public struct Event: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    public let creatorId: String
    public let creatorName: String
    public let creatorPhoto: String?
    public let latitude: Double
    public let longitude: Double
    public let locality: String?
    public let eventDate: String
    public let rsvpCount: Int?
    public let isRsvped: Bool
    public let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, locality
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case creatorPhoto = "creator_photo"
        case eventDate = "event_date"
        case rsvpCount = "rsvp_count"
        case isRsvped = "is_rsvped"
        case createdAt = "created_at"
    }
}

public struct EventListResponse: Decodable {
    public let events: [Event]?
}

public struct EventCreateResponse: Decodable {
    public let success: Bool?
    public let event: Event?
}

public struct EventRsvpResponse: Decodable {
    public let success: Bool?
    public let rsvpCount: Int?

    private enum CodingKeys: String, CodingKey {
        case success
        case rsvpCount = "rsvp_count"
    }
}
