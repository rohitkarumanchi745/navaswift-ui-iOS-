import Foundation
import NavAIPrompt

/// On-device store of the user's own messages + embeddings, used to retrieve
/// style exemplars. Stays on the phone (private); it's also the raw material the
/// federated LoRA trainer samples from locally.
public actor UserStyleStore {

    private let userID: String
    private let capacity: Int
    private let fileURL: URL

    /// In-memory mirror of the persisted exemplars.
    private var exemplars: [StyleExemplar] = []

    public init(userID: String, capacity: Int = 300) {
        self.userID = userID
        self.capacity = capacity

        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("NavAI/style", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("\(userID).json")

        load()
    }

    public var count: Int { exemplars.count }

    /// Record a message the user sent, with its embedding. `weight` should be
    /// higher for messages that earned a reply/match. Keeps the newest `capacity`.
    public func add(text: String, embedding: [Float], weight: Float = 1) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !embedding.isEmpty else { return }
        exemplars.append(StyleExemplar(text: text, embedding: embedding, weight: weight))
        if exemplars.count > capacity {
            exemplars.removeFirst(exemplars.count - capacity)
        }
        persist()
    }

    /// Retrieve the `topK` exemplars closest to `query`.
    public func topExemplars(query: [Float], topK: Int) -> [StyleExemplar] {
        StyleRetrieval.selectExemplars(query: query, from: exemplars, topK: topK)
    }

    /// All exemplars (e.g. for the local trainer to sample). Copy, not a reference.
    public func allExemplars() -> [StyleExemplar] { exemplars }

    public func clear() {
        exemplars.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([StoredExemplar].self, from: data) else { return }
        exemplars = stored.map { StyleExemplar(text: $0.t, embedding: $0.e, weight: $0.w) }
    }

    private func persist() {
        let stored = exemplars.map { StoredExemplar(t: $0.text, e: $0.embedding, w: $0.weight) }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Compact on-disk shape (short keys keep the JSON small — embeddings dominate).
    private struct StoredExemplar: Codable {
        let t: String
        let e: [Float]
        let w: Float
    }
}
