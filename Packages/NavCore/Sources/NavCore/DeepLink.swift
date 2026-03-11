import Foundation

/// Represents a navigation destination triggered by a push notification or universal link.
public enum DeepLink: Equatable {
    /// Navigate to the chat tab and open a specific conversation.
    case chat(matchId: String)
    /// Navigate to the matches/likes tab.
    case matches
    /// Navigate to a specific match detail.
    case matchDetail(matchId: String)
    /// Navigate to the reels tab.
    case reels
    /// Navigate to the profile tab.
    case profile
    /// Navigate to a reel message conversation.
    case reelMessage(reelId: String, senderId: String)

    /// The tab index this deep link should activate in MainTabView.
    public var tabIndex: Int {
        switch self {
        case .chat: return 3
        case .matches, .matchDetail: return 2
        case .reels, .reelMessage: return 0
        case .profile: return 4
        }
    }

    /// Attempts to parse a deep link from push notification userInfo payload.
    /// Expected keys: "type" (match|like|super_like|message|read_receipt) and "match_id".
    public static func from(userInfo: [AnyHashable: Any]) -> DeepLink? {
        let type = userInfo["type"] as? String ?? ""
        let matchId = userInfo["match_id"] as? String

        switch type {
        case "message", "read_receipt":
            if let matchId {
                return .chat(matchId: matchId)
            }
            return .chat(matchId: "")
        case "match", "like", "super_like":
            if let matchId {
                return .matchDetail(matchId: matchId)
            }
            return .matches
        case "reel_message":
            let reelId = userInfo["reel_id"] as? String ?? ""
            let senderId = userInfo["sender_id"] as? String ?? ""
            return .reelMessage(reelId: reelId, senderId: senderId)
        default:
            return nil
        }
    }
}
