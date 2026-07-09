import Foundation

/// Builds the model prompt from a `ConversationContext` and parses the model's
/// free-text output back into clean, bounded suggestion strings.
///
/// Both halves are pure and deterministic so they can be unit-tested without a
/// model, and reused verbatim by the server-side path.
public enum SuggestionPrompt {

    /// Sentinel the model is asked to emit when done, so generation can stop
    /// cleanly instead of rambling. Stripped during parsing.
    public static let endMarker = "<END>"

    /// Stop strings to pass to the sampler.
    public static let stopSequences: [String] = [endMarker]

    /// Longest suggestion we keep; anything longer is trimmed at a word boundary.
    public static let maxSuggestionLength = 200

    // MARK: - Prompt construction

    public static func build(_ context: ConversationContext) -> String {
        let n = context.maxSuggestions
        let me = context.myName?.trimmedNonEmpty ?? "the user"
        let them = context.matchName?.trimmedNonEmpty ?? "their match"

        var lines: [String] = []
        switch context.kind {
        case .opener:
            lines.append("You are helping \(me) start a conversation with \(them) on a dating app.")
            if let blurb = context.matchBlurb?.trimmedNonEmpty {
                lines.append("\(them)'s profile: \(blurb)")
            }
            lines.append("Suggest \(n) \(context.tone.instruction) opening messages.")
        case .reply:
            lines.append("You are helping \(me) reply to \(them) on a dating app.")
            lines.append("Suggest \(n) \(context.tone.instruction) replies to \(them)'s last message.")
        }

        lines.append(
            "Rules: each suggestion on its own line, numbered 1 to \(n). "
            + "Keep each under 20 words. Sound like a real person, not an assistant. "
            + "Do not repeat their message. Output only the suggestions, then \(endMarker)."
        )

        // Personalization: show the user their own past messages so the model
        // matches their voice. This is the retrieval half of per-user style.
        let exemplars = context.styleExemplars.compactMap { $0.trimmedNonEmpty }.prefix(5)
        if !exemplars.isEmpty {
            lines.append("")
            lines.append("Match \(me)'s voice — examples of messages \(me) has sent:")
            for ex in exemplars {
                lines.append("- \(ex.collapsedWhitespace)")
            }
        }

        if !context.recentTurns.isEmpty {
            lines.append("")
            lines.append("Conversation:")
            for turn in context.recentTurns {
                let speaker = turn.author == .me ? me : them
                lines.append("\(speaker): \(turn.text.collapsedWhitespace)")
            }
        }

        lines.append("")
        lines.append(context.kind == .opener ? "Openers:" : "Replies:")
        lines.append("1.")   // prime the model to produce a numbered list

        return lines.joined(separator: "\n")
    }

    // MARK: - Output parsing

    /// Turn raw model output into at most `maxSuggestions` clean lines.
    public static func parse(_ raw: String, maxSuggestions: Int) -> [String] {
        // Everything after the end marker is noise.
        var text = raw
        if let range = text.range(of: endMarker) {
            text = String(text[..<range.lowerBound])
        }

        var results: [String] = []
        var seen = Set<String>()

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            line = stripLeadingMarker(line)
            line = stripSurroundingQuotes(line)
            line = line.collapsedWhitespace

            guard isUsable(line) else { continue }

            line = truncateAtWordBoundary(line, limit: maxSuggestionLength)

            let key = line.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            results.append(line)
            if results.count >= maxSuggestions { break }
        }

        return results
    }

    // MARK: - Helpers

    /// Drop a leading list marker: "1.", "2)", "3:", "-", "*", "•".
    static func stripLeadingMarker(_ input: String) -> String {
        var s = Substring(input)

        // Numeric marker: digits followed by . ) : or -
        if let first = s.first, first.isNumber {
            var idx = s.startIndex
            while idx < s.endIndex, s[idx].isNumber { idx = s.index(after: idx) }
            if idx < s.endIndex, ".):-".contains(s[idx]) {
                s = s[s.index(after: idx)...]
                return String(s).trimmingCharacters(in: .whitespaces)
            }
        }

        // Bullet marker.
        if let first = s.first, "-*•".contains(first) {
            s = s.dropFirst()
            return String(s).trimmingCharacters(in: .whitespaces)
        }

        return input
    }

    /// Remove matched wrapping quotes (straight or curly).
    static func stripSurroundingQuotes(_ input: String) -> String {
        guard let first = input.first, let last = input.last, input.count >= 2 else { return input }
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("\u{201C}", "\u{201D}"), ("\u{2018}", "\u{2019}")]
        for (open, close) in pairs where first == open && last == close {
            return String(input.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return input
    }

    /// Reject empties and lines that are clearly the model echoing scaffolding.
    static func isUsable(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        // A single stray marker or punctuation.
        guard line.contains(where: { $0.isLetter }) else { return false }

        let lowered = line.lowercased()
        let echoes = ["conversation:", "replies:", "openers:", "rules:", "suggestion", "here are", "sure,"]
        for prefix in echoes where lowered.hasPrefix(prefix) { return false }
        // Echoed speaker lines like "Them: ..." / "You: ...".
        if let colon = line.firstIndex(of: ":"), line.distance(from: line.startIndex, to: colon) <= 12 {
            let speaker = line[..<colon].lowercased()
            if ["them", "you", "me", "user", "match"].contains(speaker) { return false }
        }
        return true
    }

    /// Truncate to `limit` characters without cutting a word in half.
    static func truncateAtWordBoundary(_ input: String, limit: Int) -> String {
        guard input.count > limit else { return input }
        let clipped = String(input.prefix(limit))
        if let lastSpace = clipped.lastIndex(of: " ") {
            return String(clipped[..<lastSpace]).trimmingCharacters(in: .whitespaces)
        }
        return clipped
    }
}

// MARK: - String conveniences

extension String {
    /// Trimmed, or nil if empty after trimming.
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Collapse runs of whitespace/newlines into single spaces.
    var collapsedWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
