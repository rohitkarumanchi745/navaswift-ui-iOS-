import Foundation

/// Produces embedding vectors for text. The concrete backend — Harrier running
/// on-device (via bitnet.cpp) or a hosted embedding API — is swappable; the rest
/// of the personalization stack only depends on this protocol.
public protocol EmbeddingProvider: Sendable {
    /// Embed a batch of texts. Returned vectors are in input order, each of
    /// length `dimension`.
    func embed(_ texts: [String]) async throws -> [[Float]]

    /// Vector dimension this provider emits.
    var dimension: Int { get }
}

public extension EmbeddingProvider {
    /// Convenience for a single text.
    func embed(_ text: String) async throws -> [Float] {
        try await embed([text]).first ?? []
    }
}

/// How to pool token vectors into one sentence vector.
public enum EmbeddingPooling: String, Sendable {
    case mean
    case cls
    case lastToken

    /// Integer expected by the C bridge (`nava_bitnet_params.pooling`).
    public var bridgeValue: Int32 {
        switch self {
        case .mean: return 0
        case .cls: return 1
        case .lastToken: return 2
        }
    }
}

/// Configuration for the Harrier reference provider.
///
/// Confirmed against the `microsoft/harrier-oss-v1-0.6b` model card + config.json:
/// - dimension 1024 (Qwen3 hidden_size), decoder-only architecture
/// - **last-token** pooling (not mean), L2-normalized
/// - max sequence length 32768 (we truncate to `maxTokens` for short chat text)
/// - it's an ASYMMETRIC retrieval model: queries need a one-sentence instruction
///   prefix, documents do not. See `formatQuery` / `embedQuery`.
public struct EmbeddingModelConfig: Sendable {
    public var modelID: String
    public var dimension: Int
    public var pooling: EmbeddingPooling
    public var normalize: Bool
    public var maxTokens: Int

    public init(
        modelID: String = "microsoft/harrier-oss-v1-0.6b",
        dimension: Int = 1024,
        pooling: EmbeddingPooling = .lastToken,
        normalize: Bool = true,
        maxTokens: Int = 512
    ) {
        self.modelID = modelID
        self.dimension = dimension
        self.pooling = pooling
        self.normalize = normalize
        self.maxTokens = maxTokens
    }

    public static let harrier = EmbeddingModelConfig()
}

/// Format a query with its task instruction, per the Qwen3-Embedding convention
/// Harrier follows. Documents are embedded as-is (no instruction).
public func formatQuery(_ text: String, instruction: String) -> String {
    "Instruct: \(instruction)\nQuery: \(text)"
}

/// Task instructions used across the app's retrieval calls. One sentence each,
/// as the model card requires.
public enum EmbeddingTask {
    /// Retrieve the user's own past messages relevant to the current chat.
    public static let styleRetrieval =
        "Given an incoming chat message, retrieve the user's own past messages that fit a similar context and voice."
    /// Retrieve candidate profiles matching a dating preference.
    public static let profileMatch =
        "Given a dating preference, retrieve candidate profiles that match it."
}

public extension EmbeddingProvider {
    /// Embed documents (stored text: the user's past messages, profiles). No
    /// instruction — Harrier only instructs the query side.
    func embedDocuments(_ texts: [String]) async throws -> [[Float]] {
        try await embed(texts)
    }

    /// Embed a query with its task instruction.
    func embedQuery(_ text: String, instruction: String) async throws -> [Float] {
        try await embed([formatQuery(text, instruction: instruction)]).first ?? []
    }
}

/// L2-normalize a vector (cosine-space). No-op for zero vectors.
public func l2Normalize(_ v: [Float]) -> [Float] {
    var norm: Float = 0
    for x in v { norm += x * x }
    norm = norm.squareRoot()
    guard norm > 0 else { return v }
    return v.map { $0 / norm }
}

/// Wraps any `EmbeddingProvider` with an in-memory LRU cache, so repeated texts
/// (common in retrieval — the same recent messages get embedded again) aren't
/// recomputed. Only cache misses hit the underlying provider.
public actor CachingEmbeddingProvider: EmbeddingProvider {
    public nonisolated let dimension: Int
    private let base: EmbeddingProvider
    private let capacity: Int
    private var cache: [String: [Float]] = [:]
    private var order: [String] = []   // LRU recency, oldest first

    public init(_ base: EmbeddingProvider, capacity: Int = 500) {
        self.base = base
        self.dimension = base.dimension
        self.capacity = capacity
    }

    public func embed(_ texts: [String]) async throws -> [[Float]] {
        var result = [[Float]?](repeating: nil, count: texts.count)
        var missIndices: [Int] = []
        var missTexts: [String] = []

        for (i, t) in texts.enumerated() {
            if let hit = cache[t] {
                result[i] = hit
                touch(t)
            } else {
                missIndices.append(i)
                missTexts.append(t)
            }
        }

        if !missTexts.isEmpty {
            let embedded = try await base.embed(missTexts)
            for (j, idx) in missIndices.enumerated() where j < embedded.count {
                result[idx] = embedded[j]
                store(missTexts[j], embedded[j])
            }
        }

        return result.map { $0 ?? [] }
    }

    /// Test/introspection hook: current cache size.
    public var cachedCount: Int { cache.count }

    private func touch(_ key: String) {
        if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
        order.append(key)
    }

    private func store(_ key: String, _ value: [Float]) {
        cache[key] = value
        touch(key)
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
