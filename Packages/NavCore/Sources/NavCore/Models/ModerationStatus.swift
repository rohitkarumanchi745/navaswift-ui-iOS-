import Foundation

/// Represents the moderation state of a piece of user content (photo, bio, etc.).
public enum ModerationStatus: String, Codable, Sendable {
    case approved
    case pending
    case flagged
    case rejected

    /// Whether the content should be blurred in the UI.
    public var isBlurred: Bool {
        switch self {
        case .flagged, .rejected: return true
        case .approved, .pending: return false
        }
    }

    /// User-facing explanation for why content was moderated.
    public var reason: String {
        switch self {
        case .approved: return "Content approved"
        case .pending: return "Content is under review"
        case .flagged: return "This photo was flagged by our safety system for a possible guideline violation."
        case .rejected: return "This photo was removed for violating community guidelines."
        }
    }

    /// Whether the user can appeal this moderation decision.
    public var canAppeal: Bool {
        self == .flagged || self == .rejected
    }
}
