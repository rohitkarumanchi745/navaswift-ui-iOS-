import Foundation

/// Deterministic, model-free suggestions. The final fallback when neither the
/// server nor the on-device model is available (model still downloading, very
/// old device, or inference error) so the feature never shows an empty state.
public enum TemplateSuggestions {

    public static func fallback(for context: ConversationContext) -> [String] {
        let name = context.matchName?.trimmedNonEmpty
        let picks: [String]
        switch context.kind {
        case .opener:
            picks = openers(name: name, blurb: context.matchBlurb?.trimmedNonEmpty)
        case .reply:
            picks = replies(name: name)
        }
        return Array(picks.prefix(context.maxSuggestions))
    }

    private static func openers(name: String?, blurb: String?) -> [String] {
        var out: [String] = []
        if let blurb, let topic = firstTopic(from: blurb) {
            out.append("Okay I have to ask about the \(topic) — tell me everything.")
        }
        if let name {
            out.append("Hey \(name)! Your profile made me smile — how's your week going?")
        } else {
            out.append("Hey! Your profile made me smile — how's your week going?")
        }
        out.append("Two truths and a lie — go. I'll guess.")
        out.append("What's something you're weirdly passionate about?")
        return out
    }

    private static func replies(name: String?) -> [String] {
        [
            "Haha that's a good one — tell me more.",
            "Okay now I'm curious, how did that go?",
            name.map { "\($0), you can't just say that and stop 😄" } ?? "You can't just say that and stop 😄",
            "Love that. What's the story behind it?",
        ]
    }

    /// Pull a short noun-ish phrase from a blurb to ground an opener.
    private static func firstTopic(from blurb: String) -> String? {
        blurb
            .split(whereSeparator: { ",.;".contains($0) })
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
