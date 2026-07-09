import Foundation

/// One of the user's own past messages, with its embedding, used as a
/// style exemplar ("write like this") for personalized suggestions.
public struct StyleExemplar: Sendable, Equatable {
    public let text: String
    public let embedding: [Float]
    /// Optional recency/quality weight (e.g. higher for messages that led to a
    /// reply or a match). Defaults to 1.
    public let weight: Float

    public init(text: String, embedding: [Float], weight: Float = 1) {
        self.text = text
        self.embedding = embedding
        self.weight = weight
    }
}

/// Pure vector math + exemplar selection. No model/network here, so it's fully
/// unit-testable and identical on device and server.
public enum StyleRetrieval {

    /// Cosine similarity of two equal-length vectors. Returns 0 for a
    /// zero/empty/mismatched vector rather than NaN.
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
    }

    /// Pick the `topK` exemplars most similar to `query`, best first.
    /// Score = cosine similarity × exemplar weight. Ties break on higher weight.
    public static func selectExemplars(
        query: [Float],
        from pool: [StyleExemplar],
        topK: Int
    ) -> [StyleExemplar] {
        guard topK > 0, !pool.isEmpty else { return [] }
        let scored = pool.map { ex -> (StyleExemplar, Float) in
            (ex, cosineSimilarity(query, ex.embedding) * ex.weight)
        }
        return scored
            .sorted { lhs, rhs in
                lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.weight > rhs.0.weight
            }
            .prefix(topK)
            .map { $0.0 }
    }

    /// Build a query vector from recent turns by mean-pooling their embeddings.
    /// Empty input → empty vector (caller should skip retrieval).
    public static func meanPool(_ vectors: [[Float]]) -> [Float] {
        guard let first = vectors.first(where: { !$0.isEmpty }) else { return [] }
        let dim = first.count
        var acc = [Float](repeating: 0, count: dim)
        var n = 0
        for v in vectors where v.count == dim {
            for i in 0..<dim { acc[i] += v[i] }
            n += 1
        }
        guard n > 0 else { return [] }
        for i in 0..<dim { acc[i] /= Float(n) }
        return acc
    }
}
