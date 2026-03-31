import Foundation
import AuthenticationServices
import CryptoKit
import NavCore

@MainActor
public class SpotifyAuthManager: ObservableObject {

    // MARK: - Published State

    @Published public var isConnected: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String?

    // MARK: - Spotify Config

    private static let clientId = "YOUR_SPOTIFY_CLIENT_ID"
    private static let redirectURI = "nava://spotify-callback"
    private static let callbackScheme = "nava"
    private static let authorizeURL = "https://accounts.spotify.com/authorize"
    private static let tokenURL = "https://accounts.spotify.com/api/token"
    private static let scopes = "user-top-read"

    // MARK: - Keychain Keys

    private static let accessTokenKey = "spotify_access_token"
    private static let refreshTokenKey = "spotify_refresh_token"
    private static let tokenExpiryKey = "spotify_token_expiry"

    // MARK: - PKCE State

    private var codeVerifier: String?

    // MARK: - Init

    public init() {
        isConnected = KeychainHelper.load(key: Self.accessTokenKey) != nil
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Auth Flow

    public func startAuth(presentationAnchor: ASPresentationAnchor) {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
        ]

        guard let url = components.url else {
            authError = "Failed to build Spotify authorization URL"
            return
        }

        isAuthenticating = true
        authError = nil

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: Self.callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.isAuthenticating = false

                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        NavLog.debug("Spotify auth cancelled by user", category: .general)
                    } else {
                        self.authError = error.localizedDescription
                        NavLog.warning("Spotify auth error: \(error.localizedDescription)", category: .general)
                    }
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.authError = "No authorization code received"
                    return
                }

                await self.exchangeCodeForToken(code: code)
            }
        }

        let provider = SpotifyPresentationProvider(anchor: presentationAnchor)
        session.presentationContextProvider = provider
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String) async {
        guard let verifier = codeVerifier else {
            authError = "Missing code verifier"
            return
        }

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": Self.clientId,
            "code_verifier": verifier,
        ]

        let bodyString = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                authError = "Token exchange failed"
                NavLog.warning("Spotify token exchange failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .network)
                return
            }

            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            storeTokens(tokenResponse)
            isConnected = true
            codeVerifier = nil
            NavLog.info("Spotify connected successfully", category: .general)
        } catch {
            authError = "Token exchange error: \(error.localizedDescription)"
            NavLog.warning("Spotify token exchange error: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Token Refresh

    public func refreshTokenIfNeeded() async -> Bool {
        guard KeychainHelper.load(key: Self.accessTokenKey) != nil else { return false }

        if let expiryString = KeychainHelper.load(key: Self.tokenExpiryKey),
           let expiryTimestamp = Double(expiryString) {
            let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
            if Date().addingTimeInterval(60) < expiryDate {
                return true
            }
        }

        guard let refreshToken = KeychainHelper.load(key: Self.refreshTokenKey) else {
            disconnect()
            return false
        }

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId,
        ]

        let bodyString = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                NavLog.warning("Spotify token refresh failed", category: .network)
                disconnect()
                return false
            }

            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            storeTokens(tokenResponse)
            NavLog.info("Spotify token refreshed", category: .general)
            return true
        } catch {
            NavLog.warning("Spotify token refresh error: \(error.localizedDescription)", category: .network)
            disconnect()
            return false
        }
    }

    // MARK: - Access Token Getter

    public func getAccessToken() async -> String? {
        let valid = await refreshTokenIfNeeded()
        guard valid else { return nil }
        return KeychainHelper.load(key: Self.accessTokenKey)
    }

    // MARK: - Disconnect

    public func disconnect() {
        KeychainHelper.delete(key: Self.accessTokenKey)
        KeychainHelper.delete(key: Self.refreshTokenKey)
        KeychainHelper.delete(key: Self.tokenExpiryKey)
        isConnected = false
        NavLog.info("Spotify disconnected", category: .general)
    }

    // MARK: - Token Storage

    private func storeTokens(_ response: SpotifyTokenResponse) {
        KeychainHelper.save(key: Self.accessTokenKey, value: response.accessToken)
        if let refreshToken = response.refreshToken {
            KeychainHelper.save(key: Self.refreshTokenKey, value: refreshToken)
        }
        let expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn)).timeIntervalSince1970
        KeychainHelper.save(key: Self.tokenExpiryKey, value: String(expiry))
    }
}

// MARK: - Spotify Token Response

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Presentation Provider

private class SpotifyPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
