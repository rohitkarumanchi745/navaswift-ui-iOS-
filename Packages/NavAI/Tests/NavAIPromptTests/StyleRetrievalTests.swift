import XCTest
@testable import NavAIPrompt

final class StyleRetrievalTests: XCTestCase {

    func testCosineSimilarity() {
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([1, 0], [1, 0]), 1, accuracy: 1e-6)
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([1, 0], [0, 1]), 0, accuracy: 1e-6)
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([1, 1], [-1, -1]), -1, accuracy: 1e-6)
    }

    func testCosineHandlesDegenerateInput() {
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([], []), 0)
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([1, 2], [1]), 0)        // mismatched dims
        XCTAssertEqual(StyleRetrieval.cosineSimilarity([0, 0], [1, 1]), 0)     // zero vector
    }

    func testSelectExemplarsRanksBySimilarityThenWeight() {
        let pool = [
            StyleExemplar(text: "far", embedding: [0, 1], weight: 1),
            StyleExemplar(text: "near", embedding: [1, 0], weight: 1),
            StyleExemplar(text: "near-heavy", embedding: [0.9, 0.1], weight: 2),
        ]
        let out = StyleRetrieval.selectExemplars(query: [1, 0], from: pool, topK: 2)
        XCTAssertEqual(out.map { $0.text }, ["near-heavy", "near"])
    }

    func testSelectExemplarsEdgeCases() {
        XCTAssertTrue(StyleRetrieval.selectExemplars(query: [1, 0], from: [], topK: 3).isEmpty)
        let pool = [StyleExemplar(text: "a", embedding: [1, 0])]
        XCTAssertTrue(StyleRetrieval.selectExemplars(query: [1, 0], from: pool, topK: 0).isEmpty)
    }

    func testMeanPool() {
        XCTAssertEqual(StyleRetrieval.meanPool([[2, 4], [4, 8]]), [3, 6])
        XCTAssertEqual(StyleRetrieval.meanPool([[1, 2], []]), [1, 2])  // ignores wrong-dim
        XCTAssertTrue(StyleRetrieval.meanPool([]).isEmpty)
    }

    func testPromptIncludesStyleExemplars() {
        let ctx = ConversationContext(
            matchName: "Priya",
            myName: "Arjun",
            recentTurns: [.init(author: .them, text: "what are you into?")],
            styleExemplars: ["lol fair enough", "okay that's actually hilarious"],
            tone: .witty
        )
        let prompt = SuggestionPrompt.build(ctx)
        XCTAssertTrue(prompt.contains("Match Arjun's voice"))
        XCTAssertTrue(prompt.contains("lol fair enough"))
    }
}
