import Foundation

/// A single message in the conversation, from the local user or the match.
public struct ConversationTurn: Sendable, Equatable {
    public enum Author: String, Sendable {
        case me       // the local user
        case them     // the match
    }

    public let author: Author
    public let text: String

    public init(author: Author, text: String) {
        self.author = author
        self.text = text
    }
}

/// Desired feel of the generated suggestions.
public enum SuggestionTone: String, Sendable, CaseIterable {
    case playful
    case warm
    case witty
    case sincere
    case casual

    /// A short instruction fragment inserted into the prompt.
    public var instruction: String {
        switch self {
        case .playful: return "playful and light"
        case .warm:    return "warm and genuine"
        case .witty:   return "witty, with a touch of humor"
        case .sincere: return "sincere and thoughtful"
        case .casual:  return "casual and relaxed"
        }
    }
}

/// What the user is asking the model to produce.
public enum SuggestionKind: Sendable {
    /// Opening line for a brand-new match (no messages yet).
    case opener
    /// Replies to the match's most recent message(s).
    case reply
}

/// Everything the suggestion engine needs to produce chat suggestions.
///
/// Deliberately free of any networking/UI types so it can be built on-device or
/// server-side and unit-tested in isolation.
public struct ConversationContext: Sendable {
    /// The match's first name, if known (used to personalize suggestions).
    public var matchName: String?
    /// The local user's first name, if known.
    public var myName: String?
    /// A short profile blurb about the match (interests, bio) to ground openers.
    public var matchBlurb: String?
    /// Recent turns, oldest → newest. Kept short; the caller trims to a window.
    public var recentTurns: [ConversationTurn]
    /// A few of the user's own past messages, used to match their voice.
    /// Populated by the retrieval layer (see StyleRetrieval); empty = generic.
    public var styleExemplars: [String]
    /// Desired tone.
    public var tone: SuggestionTone
    /// How many suggestions to return (clamped to 1...5).
    public var maxSuggestions: Int

    public init(
        matchName: String? = nil,
        myName: String? = nil,
        matchBlurb: String? = nil,
        recentTurns: [ConversationTurn] = [],
        styleExemplars: [String] = [],
        tone: SuggestionTone = .casual,
        maxSuggestions: Int = 3
    ) {
        self.matchName = matchName
        self.myName = myName
        self.matchBlurb = matchBlurb
        self.recentTurns = recentTurns
        self.styleExemplars = styleExemplars
        self.tone = tone
        self.maxSuggestions = min(max(maxSuggestions, 1), 5)
    }

    /// Opener when there are no turns yet, otherwise a reply.
    public var kind: SuggestionKind {
        recentTurns.isEmpty ? .opener : .reply
    }
}
