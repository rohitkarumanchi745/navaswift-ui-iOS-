import Foundation
import NavCore
import NavAIPrompt

/// Minimal reachability seam so NavAI doesn't depend on NavServices.
/// The app conforms its existing `NetworkMonitor` to this (it already exposes
/// `isConnected`): `extension NetworkMonitor: NetworkReachability {}`.
@MainActor
public protocol NetworkReachability: AnyObject {
    var isConnected: Bool { get }
}

/// Server-side suggestion provider (the online, higher-quality path). Implemented
/// in a later slice against the backend `/suggestions` endpoint; kept as a seam
/// so the hybrid routing is wired up now.
public protocol RemoteSuggestionProviding: Sendable {
    func suggest(_ context: ConversationContext) async throws -> [String]
}

/// Orchestrates chat suggestions across three tiers — server (online) →
/// on-device BitNet (offline) → templates — and, on-device, personalizes with
/// the user's own style (retrieval) and their LoRA adapter (per-user weights).
@MainActor
public final class SuggestionEngine {

    private let engine: BitNetEngine
    private let modelManager: BitNetModelManager
    private let reachability: NetworkReachability?
    private let remote: RemoteSuggestionProviding?
    private let contextTokens: Int32

    // Personalization (all optional — degrade to a generic shared model).
    private let userID: String?
    private let embedder: EmbeddingProvider?
    private let styleStore: UserStyleStore?
    private let adapterManager: LoRAAdapterManager?
    /// Supplies the current per-user adapter descriptor (from the server), or nil.
    private let currentAdapterSpec: (@Sendable () async -> LoRAAdapterSpec?)?
    /// How many style exemplars to inject.
    private let exemplarCount: Int

    public init(
        engine: BitNetEngine = BitNetEngine(),
        modelManager: BitNetModelManager,
        reachability: NetworkReachability? = nil,
        remote: RemoteSuggestionProviding? = nil,
        contextTokens: Int32 = 2048,
        userID: String? = nil,
        embedder: EmbeddingProvider? = nil,
        styleStore: UserStyleStore? = nil,
        adapterManager: LoRAAdapterManager? = nil,
        currentAdapterSpec: (@Sendable () async -> LoRAAdapterSpec?)? = nil,
        exemplarCount: Int = 4
    ) {
        self.engine = engine
        self.modelManager = modelManager
        self.reachability = reachability
        self.remote = remote
        self.contextTokens = contextTokens
        self.userID = userID
        self.embedder = embedder
        self.styleStore = styleStore
        self.adapterManager = adapterManager
        self.currentAdapterSpec = currentAdapterSpec
        self.exemplarCount = exemplarCount
    }

    /// Produce suggestions, never throwing — always returns something usable.
    public func suggestReplies(for context: ConversationContext) async -> [String] {
        // 1. Server path (online only).
        if reachability?.isConnected == true, let remote {
            do {
                let out = try await remote.suggest(context)
                if !out.isEmpty { return out }
            } catch {
                NavLog.warning("Remote suggestions failed, falling back on-device: \(error.localizedDescription)",
                               category: .chat)
            }
        }

        // 2. On-device BitNet (+ personalization).
        do {
            let out = try await onDevice(context)
            if !out.isEmpty { return out }
        } catch {
            NavLog.warning("On-device suggestions unavailable: \(error.localizedDescription)", category: .chat)
        }

        // 3. Guaranteed fallback.
        return TemplateSuggestions.fallback(for: context)
    }

    /// Record a message the user just sent so future suggestions match their
    /// voice (and the local trainer has data). Fire-and-forget.
    public func recordSentMessage(_ text: String, weight: Float = 1) {
        guard let embedder, let styleStore else { return }
        Task {
            // The user's own message is a *document* — no query instruction.
            guard let vectors = try? await embedder.embedDocuments([text]),
                  let vector = vectors.first else { return }
            await styleStore.add(text: text, embedding: l2Normalize(vector), weight: weight)
        }
    }

    /// Warm the offline path: download the base model and (if available) the
    /// user's adapter, ahead of when they're needed.
    public func prewarm() {
        Task { [weak self] in
            guard let self else { return }
            _ = try? await self.modelManager.ensureModel()
            if let spec = await self.currentAdapterSpec?() {
                _ = try? await self.adapterManager?.ensureAdapter(spec)
            }
        }
    }

    public var isOnDeviceReady: Bool { modelManager.isModelAvailable }

    // MARK: - Private

    private func onDevice(_ context: ConversationContext) async throws -> [String] {
        let modelURL = try await modelManager.ensureModel()
        if await engine.isLoaded == false {
            try await engine.load(modelPath: modelURL.path, contextTokens: contextTokens)
        }

        try await applyUserAdapterIfAvailable()

        var personalized = context
        personalized.styleExemplars = await retrieveStyleExemplars(for: context)

        let prompt = SuggestionPrompt.build(personalized)
        let raw = try await engine.complete(
            prompt: prompt,
            maxTokens: 96,
            temperature: 0.7,
            stop: SuggestionPrompt.stopSequences
        )
        return SuggestionPrompt.parse(raw, maxSuggestions: context.maxSuggestions)
    }

    /// Apply the user's LoRA adapter if the app can supply one; otherwise ensure
    /// we're on the base model.
    private func applyUserAdapterIfAvailable() async throws {
        guard let userID, let adapterManager, let currentAdapterSpec else {
            await engine.clearAdapter()
            return
        }
        guard let spec = await currentAdapterSpec(), spec.userID == userID else {
            await engine.clearAdapter()
            return
        }
        let path = try await adapterManager.ensureAdapter(spec).path
        try await engine.applyAdapter(path: path, userID: userID)
    }

    /// Embed the incoming context and pull the user's closest past messages.
    private func retrieveStyleExemplars(for context: ConversationContext) async -> [String] {
        guard let embedder, let styleStore else { return [] }

        // Query = the match's latest message (reply) or their blurb (opener),
        // embedded with the style-retrieval instruction (Harrier is asymmetric).
        let queryText = context.recentTurns.last(where: { $0.author == .them })?.text
            ?? context.matchBlurb
        guard let queryText,
              let vector = try? await embedder.embedQuery(queryText, instruction: EmbeddingTask.styleRetrieval)
        else { return [] }

        let exemplars = await styleStore.topExemplars(query: l2Normalize(vector), topK: exemplarCount)
        return exemplars.map { $0.text }
    }
}
