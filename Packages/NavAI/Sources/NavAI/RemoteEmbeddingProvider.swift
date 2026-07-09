import Foundation
import NavAIPrompt

/// Hosted embedding provider — POSTs texts to an embedding endpoint (e.g. a
/// Harrier inference service or your backend). Use this when the device can't
/// run the model locally, or as the online half of the hybrid. Not offline.
///
/// Expected request/response (adjust `encode`/`decode` to your service):
///   POST { "model": "...", "input": ["a", "b"] }
///   200  { "embeddings": [[...], [...]] }
public struct RemoteEmbeddingProvider: EmbeddingProvider {

    public let dimension: Int
    private let endpoint: URL
    private let modelID: String
    private let apiKey: String?
    private let session: URLSession

    public init(
        endpoint: URL,
        config: EmbeddingModelConfig = .harrier,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.dimension = config.dimension
        self.modelID = config.modelID
        self.apiKey = apiKey
        self.session = session
    }

    public func embed(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(Request(model: modelID, input: texts))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OnDeviceLLMError.inferenceFailed("embedding service HTTP \(code)")
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.embeddings
    }

    private struct Request: Encodable {
        let model: String
        let input: [String]
    }
    private struct Response: Decodable {
        let embeddings: [[Float]]
    }
}
