import XCTest
@testable import NavAIPrompt

final class TemplateSuggestionsTests: XCTestCase {

    func testOpenersPersonalizeAndGround() {
        let ctx = ConversationContext(
            matchName: "Maya",
            myName: "Sam",
            matchBlurb: "pottery, oat lattes, and long bike rides",
            tone: .playful,
            maxSuggestions: 3
        )
        let out = TemplateSuggestions.fallback(for: ctx)
        XCTAssertEqual(out.count, 3)
        XCTAssertTrue(out.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(out.contains { $0.contains("pottery") })
        XCTAssertTrue(out.contains { $0.contains("Maya") })
    }

    func testRepliesWorkWithoutName() {
        let ctx = ConversationContext(
            recentTurns: [.init(author: .them, text: "guess what I did today")],
            maxSuggestions: 2
        )
        let out = TemplateSuggestions.fallback(for: ctx)
        XCTAssertEqual(out.count, 2)
        XCTAssertTrue(out.allSatisfy { !$0.isEmpty })
    }

    func testNeverEmpty() {
        XCTAssertFalse(TemplateSuggestions.fallback(for: ConversationContext()).isEmpty)
    }
}
