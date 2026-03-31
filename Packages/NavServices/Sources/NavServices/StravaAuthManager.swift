import Foundation
import AuthenticationServices
import CryptoKit
import NavCore

@MainActor
public class StravaAuthManager: ObservableObject {

    // MARK: - Published State

    @Published public var isConnected: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authError: String?

    // MARK: - Strava Config

    private static let clientId = "YOUR_STRAVA_CLIENT_ID"
    private static let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
    private static let redirectURI = "nava://strava-callback"
    private static let callbackScheme = "nava"
    private static let authorizeURL = "https://www.strava.com/oauth/mobile/authorize"
    private static let tokenURL = "https://www.strava.com/oauth/token"
    private static let scopes = "read,activity:read_all"

    // MARK: - Keychain Keys

    private static let accessTokenKey = "strava_access_token"
    private static let refreshTokenKey = "strava_refresh_token"
    private static let tokenExpiryKey = "strava_token_expiry"
    private static let athleteIdKey = "strava_athlete_id"

    // MARK: - Init

    public init() {
        isConnected = KeychainHelper.load(key: Self.accessTokenKey) != nil
    }

    // MARK: - Auth Flow

    public func startAuth(presentationAnchor: ASPresentationAnchor) {
        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "approval_prompt", value: "auto"),
        ]

        guard let url = components.url else {
            authError = "Failed to build Strava authorization URL"
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
                        NavLog.debug("Strava auth cancelled by user", category: .general)
                    } else {
                        self.authError = error.localizedDescription
                        NavLog.warning("Strava auth error: \(error.localizedDescription)", category: .general)
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

        let provider = StravaPresentationProvider(anchor: presentationAnchor)
        session.presentationContextProvider = provider
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String) async {
        let body: [String: String] = [
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ]

        await performTokenRequest(body: body)
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

        let body: [String: String] = [
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]

        return await performTokenRefresh(body: body)
    }

    // MARK: - Access Token Getter

    public func getAccessToken() async -> String? {
        let valid = await refreshTokenIfNeeded()
        guard valid else { return nil }
        return KeychainHelper.load(key: Self.accessTokenKey)
    }

    // MARK: - Athlete ID

    public var athleteId: String? {
        KeychainHelper.load(key: Self.athleteIdKey)
    }

    // MARK: - Disconnect

    public func disconnect() {
        KeychainHelper.delete(key: Self.accessTokenKey)
        KeychainHelper.delete(key: Self.refreshTokenKey)
        KeychainHelper.delete(key: Self.tokenExpiryKey)
        KeychainHelper.delete(key: Self.athleteIdKey)
        isConnected = false
        NavLog.info("Strava disconnected", category: .general)
    }

    // MARK: - Token Network Helpers

    private func performTokenRequest(body: [String: String]) async {
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
                NavLog.warning("Strava token exchange failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)", category: .network)
                return
            }

            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            storeTokens(tokenResponse)
            isConnected = true
            NavLog.info("Strava connected successfully", category: .general)
        } catch {
            authError = "Token exchange error: \(error.localizedDescription)"
            NavLog.warning("Strava token exchange error: \(error.localizedDescription)", category: .network)
        }
    }

    private func performTokenRefresh(body: [String: String]) async -> Bool {
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
                NavLog.warning("Strava token refresh failed", category: .network)
                disconnect()
                return false
            }

            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            storeTokens(tokenResponse)
            NavLog.info("Strava token refreshed", category: .general)
            return true
        } catch {
            NavLog.warning("Strava token refresh error: \(error.localizedDescription)", category: .network)
            disconnect()
            return false
        }
    }

    // MARK: - Token Storage

    private func storeTokens(_ response: StravaTokenResponse) {
        KeychainHelper.save(key: Self.accessTokenKey, value: response.accessToken)
        KeychainHelper.save(key: Self.refreshTokenKey, value: response.refreshToken)
        let expiry = TimeInterval(response.expiresAt)
        KeychainHelper.save(key: Self.tokenExpiryKey, value: String(expiry))
        if let athlete = response.athlete {
            KeychainHelper.save(key: Self.athleteIdKey, value: String(athlete.id))
        }
    }
}

// MARK: - Strava Token Response

private struct StravaTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let tokenType: String
    let athlete: StravaAthlete?

    struct StravaAthlete: Decodable {
        let id: Int
        let firstname: String?
        let lastname: String?
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case athlete
    }
}

// MARK: - Presentation Provider

private class StravaPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
