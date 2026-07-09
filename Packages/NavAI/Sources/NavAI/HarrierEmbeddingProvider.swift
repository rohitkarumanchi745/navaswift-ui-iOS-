import Foundation
import BitNetCore
import NavAIPrompt

/// On-device embedding provider running `microsoft/harrier-oss-v1-0.6b` (GGUF)
/// through the same bitnet.cpp bridge as the generator. Fully offline.
///
/// The model context is not thread-safe, so this is an `actor`. `dimension` is
/// a `nonisolated let` so it satisfies the synchronous protocol requirement.
public actor HarrierEmbeddingProvider: EmbeddingProvider {

    public nonisolated let dimension: Int

    private let modelPath: String
    private let config: EmbeddingModelConfig
    private var handle: OpaquePointer?
    private static var backendInitialized = false

    /// - Parameters:
    ///   - modelPath: on-disk path to the Harrier GGUF (see BitNetModelManager).
    ///   - config: dimension/pooling/normalize — confirm against the model card.
    public init(modelPath: String, config: EmbeddingModelConfig = .harrier) {
        self.modelPath = modelPath
        self.config = config
        self.dimension = config.dimension
    }

    deinit {
        if let handle { nava_bitnet_free(handle) }
    }

    public func embed(_ texts: [String]) async throws -> [[Float]] {
        try ensureLoaded()
        guard let handle else { throw OnDeviceLLMError.modelNotAvailable }

        var out: [[Float]] = []
        out.reserveCapacity(texts.count)

        for text in texts {
            var buffer = [Float](repeating: 0, count: dimension)
            var errBuf = [CChar](repeating: 0, count: 256)
            let produced = buffer.withUnsafeMutableBufferPointer { buf in
                nava_bitnet_embed(handle, text, buf.baseAddress, Int32(dimension),
                                  &errBuf, Int32(errBuf.count))
            }
            if produced < 0 {
                throw OnDeviceLLMError.inferenceFailed("embed: \(String(cString: errBuf))")
            }
            var vector = Array(buffer.prefix(Int(min(produced, Int32(dimension)))))
            if config.normalize { vector = l2Normalize(vector) }
            out.append(vector)
        }
        return out
    }

    private func ensureLoaded() throws {
        if handle != nil { return }
        if !Self.backendInitialized {
            nava_bitnet_backend_init()
            Self.backendInitialized = true
        }

        var params = nava_bitnet_default_params()
        params.embeddings = true
        params.pooling = config.pooling.bridgeValue
        params.n_ctx = Int32(config.maxTokens)

        var errBuf = [CChar](repeating: 0, count: 256)
        guard let model = nava_bitnet_load(modelPath, params, &errBuf, Int32(errBuf.count)) else {
            throw OnDeviceLLMError.modelLoadFailed("embed model: \(String(cString: errBuf))")
        }
        handle = model
    }
}
