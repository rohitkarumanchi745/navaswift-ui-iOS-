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

// MARK: - Demo Data

public extension ReelInboxItem {
    static let demos: [ReelInboxItem] = [
        ReelInboxItem(
            id: "msg-1", reelId: "demo-reel-1", senderId: "demo-1",
            senderName: "Priya", senderPhoto: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
            senderAge: 26, content: "Love your sunset video! Where was that?",
            createdAt: "2026-03-10T10:30:00Z", isRead: false,
            reelCaption: "Weekend vibes in the city!"
        ),
        ReelInboxItem(
            id: "msg-2", reelId: "demo-reel-3", senderId: "demo-3",
            senderName: "Meera", senderPhoto: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400",
            senderAge: 27, content: "That cooking video was amazing!",
            createdAt: "2026-03-10T08:15:00Z", isRead: true,
            reelCaption: "Cooking something special tonight"
        ),
        ReelInboxItem(
            id: "msg-3", reelId: "demo-reel-5", senderId: "demo-5",
            senderName: "Kavya", senderPhoto: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400",
            senderAge: 24, content: "The sunset chasing reel was everything!",
            createdAt: "2026-03-09T18:45:00Z", isRead: true,
            reelCaption: "Sunset chasing is my cardio"
        ),
    ]
}

public extension ReelThreadMessage {
    static func demoThread() -> [ReelThreadMessage] {
        [
            ReelThreadMessage(id: "t-1", senderId: "demo-1", content: "Love your sunset video! Where was that?", createdAt: "2026-03-10T10:30:00Z", isMe: false),
            ReelThreadMessage(id: "t-2", senderId: "me", content: "Thanks! That was in Goa last weekend", createdAt: "2026-03-10T10:32:00Z", isMe: true),
            ReelThreadMessage(id: "t-3", senderId: "demo-1", content: "Goa is amazing! I was there last month too", createdAt: "2026-03-10T10:35:00Z", isMe: false),
            ReelThreadMessage(id: "t-4", senderId: "me", content: "No way! Which part did you visit?", createdAt: "2026-03-10T10:36:00Z", isMe: true),
        ]
    }
}
