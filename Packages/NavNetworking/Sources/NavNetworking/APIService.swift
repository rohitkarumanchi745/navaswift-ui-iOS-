import Foundation
import NavCore

// MARK: - API Errors
public enum APIError: LocalizedError {
    case networkError
    case invalidResponse
    case invalidURL(String)
    case serverError(String)
    case unauthorized
    case forbidden
    case serviceUnavailable(Int)

    public var errorDescription: String? {
        switch self {
        case .networkError: return "No internet connection. Please check your network."
        case .invalidResponse: return "Invalid response from server."
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .serverError(let msg): return msg
        case .unauthorized: return "Session expired. Please sign in again."
        case .forbidden: return "You don't have permission to do that."
        case .serviceUnavailable(let code): return "Something went wrong (error \(code)). Please try again."
        }
    }

    /// Whether this error is transient and retrying may succeed.
    public var isRetryable: Bool {
        switch self {
        case .serviceUnavailable, .networkError: return true
        default: return false
        }
    }
}

// MARK: - SSL Pinning Delegate
private final class SSLPinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard AppConfig.shared.isProduction else {
            // Skip pinning in development
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate the server certificate chain
        let policies = [SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFTypeRef)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            NavLog.error("SSL certificate validation failed: \(error?.localizedDescription ?? "unknown")", category: .network)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

// MARK: - Data Extension for Multipart
private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Metrics Callback

/// Lightweight struct for reporting request metrics from the networking layer.
/// Consumers (e.g. NetworkMetrics in NavServices) subscribe via `APIService.onMetric`.
public struct APIRequestMetric: Sendable {
    public let endpoint: String
    public let method: String
    public let statusCode: Int?
    public let latencyMs: Double
    public let error: String?
}

// MARK: - API Service
public class APIService {
    public static let shared = APIService()

    /// Subscribe to receive metrics for every completed request.
    /// Set by the app layer (e.g. NetworkMetrics) at startup.
    public var onMetric: (@Sendable (APIRequestMetric) -> Void)?

    /// Called when a 401 is received. Returns `true` if token was refreshed
    /// and the request should be retried with the new token.
    public var onUnauthorized: (() async -> Bool)?

    private let baseURL: String
    private var authToken: String?
    private let session: URLSession
    private let maxRetries = 3
    private let pinningDelegate = SSLPinningDelegate()

    private init() {
        baseURL = AppConfig.shared.apiBaseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB memory
            diskCapacity: 100 * 1024 * 1024,    // 100 MB disk
            diskPath: "nava_url_cache"
        )
        session = URLSession(configuration: config, delegate: pinningDelegate, delegateQueue: nil)
    }

    public func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - URL Builder

    private func buildURL(path: String) throws -> URL {
        let urlString = "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            NavLog.error("Invalid URL: \(urlString)", category: .network)
            throw APIError.invalidURL(urlString)
        }
        return url
    }

    // MARK: - GraphQL
    public func graphQL<T>(query: String, variables: [String: Any]? = nil) async throws -> T {
        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }

        let data = try JSONSerialization.data(withJSONObject: body)
        let url = try buildURL(path: "/graphql")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        NavLog.debug("GraphQL request to /graphql", category: .network)
        let (responseData, response) = try await performWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        NavLog.debug("GraphQL response: \(httpResponse.statusCode)", category: .network)

        if httpResponse.statusCode == 401 {
            // Attempt token refresh and retry once
            if let onUnauthorized, await onUnauthorized() {
                NavLog.info("Token refreshed after 401, retrying GraphQL", category: .network)
                var retryRequest = request
                if let token = authToken {
                    retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await performWithRetry(request: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
                if retryHttp.statusCode == 401 { throw APIError.unauthorized }
                guard let retryJson = try JSONSerialization.jsonObject(with: retryData) as? [String: Any] else {
                    throw APIError.invalidResponse
                }
                if let errors = retryJson["errors"] as? [[String: Any]] {
                    let messages = errors.compactMap { $0["message"] as? String }
                    throw APIError.serverError(messages.joined(separator: "; "))
                }
                guard let data = retryJson["data"] as? T else { throw APIError.invalidResponse }
                return data
            }
            NavLog.warning("Unauthorized (401) from GraphQL", category: .network)
            throw APIError.unauthorized
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        if let errors = json["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            let joined = messages.joined(separator: "; ")
            NavLog.error("GraphQL errors: \(joined)", category: .network)
            throw APIError.serverError(joined)
        }

        guard let data = json["data"] as? T else {
            throw APIError.invalidResponse
        }

        return data
    }

    // MARK: - Typed GraphQL (Codable)

    /// Type-safe GraphQL method that decodes the full response envelope using Codable.
    /// Usage: `let response: GraphQLResponse<MeData> = try await APIService.shared.graphQLCodable(query: ...)`
    public func graphQLCodable<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil
    ) async throws -> T {
        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = try buildURL(path: "/graphql")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        NavLog.debug("GraphQL (typed) request to /graphql", category: .network)
        let (responseData, response) = try await performWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        NavLog.debug("GraphQL (typed) response: \(httpResponse.statusCode)", category: .network)

        if httpResponse.statusCode == 401 {
            // Attempt token refresh and retry once
            if let onUnauthorized, await onUnauthorized() {
                NavLog.info("Token refreshed after 401, retrying typed GraphQL", category: .network)
                var retryRequest = request
                if let token = authToken {
                    retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await performWithRetry(request: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
                if retryHttp.statusCode == 401 { throw APIError.unauthorized }
                let envelope = try JSONDecoder().decode(GraphQLResponse<T>.self, from: retryData)
                if let errors = envelope.errors, !errors.isEmpty {
                    throw APIError.serverError(errors.map(\.message).joined(separator: "; "))
                }
                guard let data = envelope.data else { throw APIError.invalidResponse }
                return data
            }
            NavLog.warning("Unauthorized (401) from GraphQL", category: .network)
            throw APIError.unauthorized
        }

        let envelope = try JSONDecoder().decode(GraphQLResponse<T>.self, from: responseData)

        if let errors = envelope.errors, !errors.isEmpty {
            let messages = errors.map(\.message)
            let joined = messages.joined(separator: "; ")
            NavLog.error("GraphQL errors: \(joined)", category: .network)
            throw APIError.serverError(joined)
        }

        guard let data = envelope.data else {
            throw APIError.invalidResponse
        }

        return data
    }

    // MARK: - REST
    public func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        let url = try buildURL(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        NavLog.debug("POST \(path)", category: .network)
        let (responseData, response) = try await performWithRetry(request: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                if let onUnauthorized, await onUnauthorized() {
                    var retryRequest = request
                    if let token = authToken {
                        retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    let (retryData, retryResp) = try await performWithRetry(request: retryRequest)
                    if let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 401 {
                        throw APIError.unauthorized
                    }
                    return try JSONDecoder().decode(T.self, from: retryData)
                }
                throw APIError.unauthorized
            }
            try checkHTTPStatus(httpResponse, path: path)
        }

        return try JSONDecoder().decode(T.self, from: responseData)
    }

    public func get<T: Decodable>(path: String) async throws -> T {
        let url = try buildURL(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        NavLog.debug("GET \(path)", category: .network)
        let (responseData, response) = try await performWithRetry(request: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                if let onUnauthorized, await onUnauthorized() {
                    var retryRequest = request
                    if let token = authToken {
                        retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    let (retryData, retryResp) = try await performWithRetry(request: retryRequest)
                    if let retryHttp = retryResp as? HTTPURLResponse, retryHttp.statusCode == 401 {
                        throw APIError.unauthorized
                    }
                    return try JSONDecoder().decode(T.self, from: retryData)
                }
                throw APIError.unauthorized
            }
            try checkHTTPStatus(httpResponse, path: path)
        }

        return try JSONDecoder().decode(T.self, from: responseData)
    }

    // MARK: - Multipart Upload
    public func multipartUpload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fileField: String = "file",
        fields: [String: String] = [:]
    ) async throws -> T {
        let boundary = UUID().uuidString
        let url = try buildURL(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendUTF8("\(value)\r\n")
        }
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        NavLog.debug("Multipart upload to \(path) (\(fileData.count) bytes)", category: .network)
        let (responseData, response) = try await performWithRetry(request: request)
        if let httpResponse = response as? HTTPURLResponse {
            try checkHTTPStatus(httpResponse, path: path)
        }
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    // MARK: - HTTP Status Checks

    /// Checks for common HTTP error status codes and throws the appropriate APIError.
    /// 401 is handled separately per-method (token refresh logic).
    private func checkHTTPStatus(_ response: HTTPURLResponse, path: String) throws {
        switch response.statusCode {
        case 200..<400:
            break // Success range
        case 403:
            NavLog.warning("Forbidden (403) from \(path)", category: .network)
            throw APIError.forbidden
        case 400..<500:
            NavLog.warning("Client error (\(response.statusCode)) from \(path)", category: .network)
            throw APIError.serverError("Request failed (\(response.statusCode))")
        case 500...:
            NavLog.error("Server error (\(response.statusCode)) from \(path)", category: .network)
            throw APIError.serviceUnavailable(response.statusCode)
        default:
            break
        }
    }

    // MARK: - Retry Logic

    private func performWithRetry(request: URLRequest, attempt: Int = 0) async throws -> (Data, URLResponse) {
        let start = CFAbsoluteTimeGetCurrent()
        let endpoint = request.url?.path ?? "unknown"
        let method = request.httpMethod ?? "UNKNOWN"

        do {
            let result = try await session.data(for: request)
            let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let statusCode = (result.1 as? HTTPURLResponse)?.statusCode
            emitMetric(endpoint: endpoint, method: method, statusCode: statusCode, latencyMs: latencyMs, error: nil)
            return result
        } catch {
            let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000

            if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                emitMetric(endpoint: endpoint, method: method, statusCode: nil, latencyMs: latencyMs, error: "no_internet")
                NavLog.warning("No internet connection", category: .network)
                throw APIError.networkError
            }

            if attempt < maxRetries {
                let delay = Double(min(1000 * Int(pow(2.0, Double(attempt))), 10000)) / 1000.0
                NavLog.info("Retry \(attempt + 1)/\(maxRetries) after \(delay)s", category: .network)
                try await Task.sleep(for: .seconds(delay))
                return try await performWithRetry(request: request, attempt: attempt + 1)
            }

            emitMetric(endpoint: endpoint, method: method, statusCode: nil, latencyMs: latencyMs, error: error.localizedDescription)
            NavLog.error("Request failed after \(maxRetries) retries: \(error.localizedDescription)", category: .network)
            throw error
        }
    }

    // MARK: - Metrics Emission

    private func emitMetric(endpoint: String, method: String, statusCode: Int?, latencyMs: Double, error: String?) {
        let metric = APIRequestMetric(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            latencyMs: latencyMs,
            error: error
        )
        onMetric?(metric)
    }
}
