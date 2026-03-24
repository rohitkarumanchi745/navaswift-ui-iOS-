import Foundation

// MARK: - Match Status

public enum ReelMatchStatus: String, Codable {
    case chatting
    case eligible
    case requestSent = "request_sent"
    case requestReceived = "request_received"
    case matched
}

// MARK: - Inbox Item (GET /reels/inbox)

public struct ReelInboxItem: Identifiable, Codable {
    public let id: String
    public let reelId: String
    public let senderId: String
    public let senderName: String
    public let senderPhoto: String
    public let senderAge: Int?
    public let content: String
    public let createdAt: String
    public let isRead: Bool
    public let reelThumbnail: String?
    public let reelCaption: String?

    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case reelId = "reel_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderPhoto = "sender_photo"
        case senderAge = "sender_age"
        case content
        case createdAt = "created_at"
        case isRead = "is_read"
        case reelThumbnail = "reel_thumbnail"
        case reelCaption = "reel_caption"
    }

    public init(id: String, reelId: String, senderId: String, senderName: String,
                senderPhoto: String, senderAge: Int? = nil, content: String,
                createdAt: String, isRead: Bool, reelThumbnail: String? = nil,
                reelCaption: String? = nil) {
        self.id = id; self.reelId = reelId; self.senderId = senderId
        self.senderName = senderName; self.senderPhoto = senderPhoto
        self.senderAge = senderAge; self.content = content
        self.createdAt = createdAt; self.isRead = isRead
        self.reelThumbnail = reelThumbnail; self.reelCaption = reelCaption
    }
}

// MARK: - Inbox Response

public struct ReelInboxResponse: Codable {
    public let messages: [ReelInboxItem]
    public let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case messages
        case unreadCount = "unread_count"
    }
}

// MARK: - Thread Message (GET /reels/conversation)

public struct ReelThreadMessage: Identifiable, Codable {
    public let id: String
    public let senderId: String
    public let content: String
    public let createdAt: String
    public let isMe: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "message_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
        case isMe = "is_me"
    }

    public init(id: String, senderId: String, content: String,
                createdAt: String, isMe: Bool? = nil) {
        self.id = id; self.senderId = senderId; self.content = content
        self.createdAt = createdAt; self.isMe = isMe
    }
}

// MARK: - Conversation Response

public struct ReelConversationResponse: Codable {
    public let messages: [ReelThreadMessage]
    public let matchStatus: ReelMatchStatus
    public let canRequestMatch: Bool
    public let matchId: String?

    enum CodingKeys: String, CodingKey {
        case messages
        case matchStatus = "match_status"
        case canRequestMatch = "can_request_match"
        case matchId = "match_id"
    }
}

// MARK: - Send Message Response (POST /reels/message)

public struct ReelSendMessageResponse: Codable {
    public let messageId: Int?
    public let effortScore: Double?
    public let sent: Bool?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case effortScore = "effort_score"
        case sent
    }
}

// MARK: - Reply Response (POST /reels/reply)

public struct ReelReplyResponse: Codable {
    public let replyId: Int?
    public let responseTimeSec: Int?
    public let conversationContinued: Bool?

    enum CodingKeys: String, CodingKey {
        case replyId = "reply_id"
        case responseTimeSec = "response_time_sec"
        case conversationContinued = "conversation_continued"
    }
}

// MARK: - Match Request Response (POST /reels/match-request)

public struct ReelMatchRequestResponse: Codable {
    public let requestSent: Bool?
    public let status: ReelMatchStatus?
    public let isMatch: Bool?

    enum CodingKeys: String, CodingKey {
        case requestSent = "request_sent"
        case status
        case isMatch = "is_match"
    }
}

// MARK: - Match Accept Response (POST /reels/match-accept)

public struct ReelMatchAcceptResponse: Codable {
    public let accepted: Bool?
    public let isMatch: Bool?
    public let matchId: String?
    public let status: ReelMatchStatus?

    enum CodingKeys: String, CodingKey {
        case accepted
        case isMatch = "is_match"
        case matchId = "match_id"
        case status
    }
}

// MARK: - Reel Activity Item (GET /reels/activity)

public struct ReelActivityItem: Identifiable, Codable {
    public let id: String
    public let type: String           // "like", "view", "message", "like_creator"
    public let reelId: String
    public let reelCaption: String?
    public let actorId: String
    public let actorName: String
    public let actorPhoto: String
    public let actorAge: Int?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "activity_id"
        case type
        case reelId = "reel_id"
        case reelCaption = "reel_caption"
        case actorId = "actor_id"
        case actorName = "actor_name"
        case actorPhoto = "actor_photo"
        case actorAge = "actor_age"
        case createdAt = "created_at"
    }

    public init(id: String, type: String, reelId: String, reelCaption: String? = nil,
                actorId: String, actorName: String, actorPhoto: String,
                actorAge: Int? = nil, createdAt: String) {
        self.id = id; self.type = type; self.reelId = reelId
        self.reelCaption = reelCaption; self.actorId = actorId
        self.actorName = actorName; self.actorPhoto = actorPhoto
        self.actorAge = actorAge; self.createdAt = createdAt
    }

    public var icon: String {
        switch type {
        case "like": return "heart.fill"
        case "view": return "eye.fill"
        case "message": return "bubble.left.fill"
        case "like_creator": return "hand.thumbsup.fill"
        default: return "bell.fill"
        }
    }

    public var iconColor: String {
        switch type {
        case "like": return "FF8A9E"
        case "view": return "7BB3FF"
        case "message": return "C9A0DC"
        case "like_creator": return "4ECDC4"
        default: return "FFFFFF"
        }
    }

    public var activityDescription: String {
        switch type {
        case "like": return "liked your reel"
        case "view": return "viewed your reel"
        case "message": return "messaged on your reel"
        case "like_creator": return "liked you from your reel"
        default: return "interacted with your reel"
        }
    }
}

public struct ReelActivityResponse: Codable {
    public let activities: [ReelActivityItem]
    public let totalLikes: Int?
    public let totalViews: Int?
    public let totalMessages: Int?

    enum CodingKeys: String, CodingKey {
        case activities
        case totalLikes = "total_likes"
        case totalViews = "total_views"
        case totalMessages = "total_messages"
    }
}

