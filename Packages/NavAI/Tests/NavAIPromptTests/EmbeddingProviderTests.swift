import XCTest
@testable import NavAIPrompt

private actor CountingProvider: EmbeddingProvider {
    nonisolated let dimension = 3
    private var calls = 0
    private var totalTexts = 0
    func embed(_ texts: [String]) async throws -> [[Float]] {
        calls += 1
        totalTexts += texts.count
        return texts.map { [Float($0.count), 0, 0] }
    }
    func stats() -> (calls: Int, texts: Int) { (calls, totalTexts) }
}

final class EmbeddingProviderTests: XCTestCase {

    func testHarrierConfigDefaults() {
        XCTAssertEqual(EmbeddingModelConfig.harrier.modelID, "microsoft/harrier-oss-v1-0.6b")
        XCTAssertEqual(EmbeddingModelConfig.harrier.dimension, 1024)
        XCTAssertEqual(EmbeddingModelConfig.harrier.pooling, .mean)
    }

    func testPoolingBridgeValues() {
        XCTAssertEqual(EmbeddingPooling.mean.bridgeValue, 0)
        XCTAssertEqual(EmbeddingPooling.cls.bridgeValue, 1)
        XCTAssertEqual(EmbeddingPooling.lastToken.bridgeValue, 2)
    }

    func testL2Normalize() {
        let n = l2Normalize([3, 4])
        XCTAssertEqual(n[0], 0.6, accuracy: 1e-6)
        XCTAssertEqual(n[1], 0.8, accuracy: 1e-6)
        XCTAssertEqual(l2Normalize([0, 0]), [0, 0])
    }

    func testCacheOnlyMissesHitBase() async throws {
        let base = CountingProvider()
        let cache = CachingEmbeddingProvider(base, capacity: 10)

        _ = try await cache.embed(["a", "b"])   // both miss
        _ = try await cache.embed(["a", "b"])   // both hit
        _ = try await cache.embed(["a", "c"])   // c miss

        let stats = await base.stats()
        XCTAssertEqual(stats.calls, 2)          // only the two miss batches
        XCTAssertEqual(stats.texts, 3)          // a, b, c — each once
        let cached = await cache.cachedCount
        XCTAssertEqual(cached, 3)
        XCTAssertEqual(cache.dimension, 3)
    }

    func testCacheEviction() async throws {
        let base = CountingProvider()
        let cache = CachingEmbeddingProvider(base, capacity: 2)
        _ = try await cache.embed(["a"])
        _ = try await cache.embed(["b"])
        _ = try await cache.embed(["c"])        // evicts "a"
        let cached = await cache.cachedCount
        XCTAssertEqual(cached, 2)
    }
}
