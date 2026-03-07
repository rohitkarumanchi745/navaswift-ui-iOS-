import Foundation

// MARK: - API Errors
public enum APIError: LocalizedError {
    case networkError
    case invalidResponse
    case serverError(String)
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .networkError: return "No internet connection. Please check your network."
        case .invalidResponse: return "Invalid response from server."
        case .serverError(let msg): return msg
        case .unauthorized: return "Session expired. Please sign in again."
        }
    }
}

// MARK: - API Service
public class APIService {
    public static let shared = APIService()

    private let baseURL: String
    private var authToken: String?
    private let session: URLSession
    private let maxRetries = 3

    private init() {
        baseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? AppConfig.shared.apiBaseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    public func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - GraphQL
    public func graphQL<T>(query: String, variables: [String: Any]? = nil) async throws -> T {
        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }

        let data = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "\(baseURL)/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        let (responseData, response) = try await performWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        if let errors = json["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            throw APIError.serverError(messages.joined(separator: "; "))
        }

        guard let data = json["data"] as? T else {
            throw APIError.invalidResponse
        }

        return data
    }

    // MARK: - REST
    public func post<T: Decodable>(path: String, body: [String: Any]) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        let (responseData, _) = try await performWithRetry(request: request)
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    public func get<T: Decodable>(path: String) async throws -> T {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (responseData, _) = try await performWithRetry(request: request)
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
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        let (responseData, _) = try await performWithRetry(request: request)
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    // MARK: - Retry Logic
    private func performWithRetry(request: URLRequest, attempt: Int = 0) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            if attempt < maxRetries {
                if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    throw APIError.networkError
                }

                let delay = Double(min(1000 * Int(pow(2.0, Double(attempt))), 10000)) / 1000.0
                try await Task.sleep(for: .seconds(delay))
                return try await performWithRetry(request: request, attempt: attempt + 1)
            }

            throw error
        }
    }
}
