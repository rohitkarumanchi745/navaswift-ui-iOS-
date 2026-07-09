import XCTest
@testable import NavAIPrompt

final class SuggestionPromptTests: XCTestCase {

    // MARK: - Parsing

    func testParsesNumberedList() {
        let raw = """
        1. Hey! How's your week going?
        2. That hiking photo is stunning — where was it?
        3. Coffee or cocktails person?
        <END>
        """
        let out = SuggestionPrompt.parse(raw, maxSuggestions: 3)
        XCTAssertEqual(out, [
            "Hey! How's your week going?",
            "That hiking photo is stunning — where was it?",
            "Coffee or cocktails person?",
        ])
    }

    func testStopsAtEndMarkerAndIgnoresTrailingJunk() {
        let raw = "1. First\n2. Second\n<END>\n3. Should be ignored\nrambling nonsense"
        let out = SuggestionPrompt.parse(raw, maxSuggestions: 5)
        XCTAssertEqual(out, ["First", "Second"])
    }

    func testHonorsMaxSuggestions() {
        let raw = "1. a real reply\n2. another real reply\n3. a third reply\n4. a fourth reply"
        XCTAssertEqual(SuggestionPrompt.parse(raw, maxSuggestions: 2).count, 2)
    }

    func testStripsBulletsQuotesAndDedupes() {
        let raw = """
        - "Nice to meet you!"
        • Nice to meet you!
        * Tell me about your dog
        """
        let out = SuggestionPrompt.parse(raw, maxSuggestions: 5)
        XCTAssertEqual(out, ["Nice to meet you!", "Tell me about your dog"])
    }

    func testDropsEchoedScaffolding() {
        let raw = """
        Here are some suggestions:
        Replies:
        Them: what are you up to?
        1. Just grabbing coffee, you?
        """
        let out = SuggestionPrompt.parse(raw, maxSuggestions: 3)
        XCTAssertEqual(out, ["Just grabbing coffee, you?"])
    }

    func testTruncatesOverlongSuggestionAtWordBoundary() {
        let long = String(repeating: "word ", count: 100).trimmingCharacters(in: .whitespaces)
        let out = SuggestionPrompt.parse("1. \(long)", maxSuggestions: 1)
        XCTAssertEqual(out.count, 1)
        XCTAssertLessThanOrEqual(out[0].count, SuggestionPrompt.maxSuggestionLength)
        XCTAssertFalse(out[0].hasSuffix("wor"), "should not cut a word in half")
    }

    func testEmptyOutputYieldsNoSuggestions() {
        XCTAssertTrue(SuggestionPrompt.parse("\n\n  \n", maxSuggestions: 3).isEmpty)
        XCTAssertTrue(SuggestionPrompt.parse("1.\n2)\n- ", maxSuggestions: 3).isEmpty)
    }

    // MARK: - Marker stripping units

    func testStripLeadingMarkerVariants() {
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("1. hello"), "hello")
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("12) hello"), "hello")
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("3: hello"), "hello")
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("- hello"), "hello")
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("• hello"), "hello")
        // A sentence that merely starts with a number shouldn't be mangled.
        XCTAssertEqual(SuggestionPrompt.stripLeadingMarker("100 days of summer, right?"),
                       "100 days of summer, right?")
    }

    // MARK: - Prompt building

    func testOpenerPromptWhenNoTurns() {
        let ctx = ConversationContext(
            matchName: "Priya",
            myName: "Arjun",
            matchBlurb: "loves trail running and filter coffee",
            tone: .playful,
            maxSuggestions: 3
        )
        XCTAssertEqual(ctx.kind, .opener)
        let prompt = SuggestionPrompt.build(ctx)
        XCTAssertTrue(prompt.contains("start a conversation with Priya"))
        XCTAssertTrue(prompt.contains("trail running"))
        XCTAssertTrue(prompt.contains("Openers:"))
        XCTAssertTrue(prompt.hasSuffix("1."))
    }

    func testReplyPromptIncludesConversation() {
        let ctx = ConversationContext(
            matchName: "Priya",
            myName: "Arjun",
            recentTurns: [
                .init(author: .them, text: "hey! how was your weekend?"),
                .init(author: .me, text: "pretty good, went climbing"),
                .init(author: .them, text: "no way, where do you climb?"),
            ],
            tone: .warm
        )
        XCTAssertEqual(ctx.kind, .reply)
        let prompt = SuggestionPrompt.build(ctx)
        XCTAssertTrue(prompt.contains("reply to Priya"))
        XCTAssertTrue(prompt.contains("Conversation:"))
        XCTAssertTrue(prompt.contains("Priya: no way, where do you climb?"))
        XCTAssertTrue(prompt.contains("Replies:"))
    }

    func testMaxSuggestionsClamped() {
        XCTAssertEqual(ConversationContext(maxSuggestions: 99).maxSuggestions, 5)
        XCTAssertEqual(ConversationContext(maxSuggestions: 0).maxSuggestions, 1)
    }
}
