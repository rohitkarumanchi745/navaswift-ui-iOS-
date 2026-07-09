import Foundation
import BitNetCore
import NavAIPrompt

/// Owns a single loaded BitNet model and runs inference on it.
///
/// The underlying C context is not thread-safe, so the entire engine is an
/// `actor`: every completion is serialized onto the actor's executor (off the
/// main thread). A completion blocks that executor for its duration, which is
/// intended — one model, one in-flight request.
public actor BitNetEngine {

    private var handle: OpaquePointer?
    private var adapterHandle: OpaquePointer?
    /// Which user's adapter is currently applied (nil = base model).
    private var appliedAdapterUserID: String?
    private static var backendInitialized = false

    public init() {}

    deinit {
        if let adapterHandle { nava_bitnet_adapter_free(adapterHandle) }
        if let handle { nava_bitnet_free(handle) }
    }

    public var isLoaded: Bool { handle != nil }

    /// The user whose LoRA adapter is currently applied, if any.
    public var currentAdapterUserID: String? { appliedAdapterUserID }

    /// Load a GGUF model from disk, replacing any currently loaded one.
    public func load(modelPath: String, contextTokens: Int32 = 2048) throws {
        if !Self.backendInitialized {
            nava_bitnet_backend_init()
            Self.backendInitialized = true
        }
        if let existing = handle {
            nava_bitnet_free(existing)
            handle = nil
        }

        var params = nava_bitnet_default_params()
        params.n_ctx = contextTokens

        var errBuf = [CChar](repeating: 0, count: 256)
        guard let model = nava_bitnet_load(modelPath, params, &errBuf, Int32(errBuf.count)) else {
            throw OnDeviceLLMError.modelLoadFailed(String(cString: errBuf))
        }
        handle = model
    }

    public func unload() {
        clearAdapter()
        if let handle {
            nava_bitnet_free(handle)
            self.handle = nil
        }
    }

    // MARK: - Per-user LoRA adapters

    /// Apply a per-user LoRA adapter (GGUF on disk) on top of the shared base.
    /// Idempotent for the same user: re-applying the same `userID` is a no-op.
    public func applyAdapter(path: String, userID: String, scale: Float = 1.0) throws {
        guard let handle else { throw OnDeviceLLMError.modelNotAvailable }
        if appliedAdapterUserID == userID, adapterHandle != nil { return }

        // Drop any previously loaded adapter.
        if let existing = adapterHandle {
            nava_bitnet_clear_adapters(handle)
            nava_bitnet_adapter_free(existing)
            adapterHandle = nil
            appliedAdapterUserID = nil
        }

        var errBuf = [CChar](repeating: 0, count: 256)
        guard let adapter = nava_bitnet_adapter_load(handle, path, &errBuf, Int32(errBuf.count)) else {
            throw OnDeviceLLMError.modelLoadFailed("adapter: \(String(cString: errBuf))")
        }
        if nava_bitnet_set_adapter(handle, adapter, scale) != 0 {
            nava_bitnet_adapter_free(adapter)
            throw OnDeviceLLMError.inferenceFailed("failed to apply adapter")
        }
        adapterHandle = adapter
        appliedAdapterUserID = userID
    }

    /// Revert to the shared base model (no personalization).
    public func clearAdapter() {
        if let handle { nava_bitnet_clear_adapters(handle) }
        if let existing = adapterHandle {
            nava_bitnet_adapter_free(existing)
            adapterHandle = nil
        }
        appliedAdapterUserID = nil
    }

    /// Run a completion and return the full generated text. `onToken`, if given,
    /// receives each token as it's produced; return `false` from it to cancel.
    public func complete(
        prompt: String,
        maxTokens: Int32 = 96,
        temperature: Float = 0.7,
        stop: [String] = SuggestionPrompt.stopSequences,
        onToken: (@Sendable (String) -> Bool)? = nil
    ) throws -> String {
        guard let handle else { throw OnDeviceLLMError.modelNotAvailable }

        var sampling = nava_bitnet_default_sampling()
        sampling.max_tokens = maxTokens
        sampling.temperature = temperature

        // NULL-terminated C array of stop strings (each strdup'd, freed on exit).
        let stopDup = stop.map { strdup($0) }
        defer { stopDup.forEach { free($0) } }
        var stopPtrs: [UnsafePointer<CChar>?] = stopDup.map { $0.map { UnsafePointer($0) } }
        stopPtrs.append(nil)

        // Streaming bridge: a reference box passed through the C `user_data`.
        final class Sink {
            var text = ""
            let onToken: (@Sendable (String) -> Bool)?
            init(_ cb: (@Sendable (String) -> Bool)?) { onToken = cb }
            func append(_ piece: String) -> Bool {
                text += piece
                return onToken?(piece) ?? true
            }
        }
        let sink = Sink(onToken)
        let sinkPtr = Unmanaged.passUnretained(sink).toOpaque()

        let callback: nava_bitnet_token_cb = { cText, user in
            guard let cText, let user else { return true }
            let sink = Unmanaged<Sink>.fromOpaque(user).takeUnretainedValue()
            return sink.append(String(cString: cText))
        }

        var errBuf = [CChar](repeating: 0, count: 256)
        let produced = stopPtrs.withUnsafeBufferPointer { buf -> Int32 in
            sampling.stop = buf.baseAddress
            return nava_bitnet_complete(handle, prompt, sampling, callback, sinkPtr,
                                        &errBuf, Int32(errBuf.count))
        }

        if produced < 0 {
            throw OnDeviceLLMError.inferenceFailed(String(cString: errBuf))
        }
        return sink.text
    }
}
