import SwiftUI
import Security
import NavCore
import NavNetworking

// MARK: - Auth Status
public enum AuthStatus: Equatable, Hashable {
    case loading, unauthenticated, authenticated, sessionExpired
}

// MARK: - Keychain Helper
private struct KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            NavLog.warning("Keychain save failed for \(key): \(status)", category: .auth)
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            NavLog.warning("Keychain delete failed for \(key): \(status)", category: .auth)
        }
    }
}

// MARK: - JWT Helper
private struct JWTHelper {
    struct Claims {
        let sub: String?
        let exp: Date?
        let isAdmin: Bool
    }

    static func decode(_ token: String) -> Claims? {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payloadData = base64URLDecode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }

        let sub = json["sub"] as? String
        let isAdmin = json["is_admin"] as? Bool ?? false
        var exp: Date?
        if let expTimestamp = json["exp"] as? TimeInterval {
            exp = Date(timeIntervalSince1970: expTimestamp)
        }
        return Claims(sub: sub, exp: exp, isAdmin: isAdmin)
    }

    static func isExpired(_ token: String, bufferSeconds: TimeInterval = 60) -> Bool {
        guard let claims = decode(token), let exp = claims.exp else {
            return true
        }
        return Date().addingTimeInterval(bufferSeconds) >= exp
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

// MARK: - Auth Manager
@MainActor
public class AuthManager: ObservableObject {
    @Published public var status: AuthStatus = .loading
    @Published public var user: UserProfile?
    @Published public var token: String?
    @Published public var isRefreshingProfile = false

    /// Called during logout so the app layer can clean up (e.g. unregister push token, clear badge).
    public var onLogout: (() -> Void)?

    private let tokenKey = "nava_token"
    private let refreshTokenKey = "nava_refresh_token"
    private let phoneKey = "nava_phone"
    private let userIdKey = "nava_user_id"
    private var isRefreshingToken = false

    public init() {
        bootstrapAuth()
    }

    private func bootstrapAuth() {
        guard let storedToken = KeychainHelper.load(key: tokenKey) else {
            NavLog.debug("bootstrapAuth: no valid token, setting unauthenticated", category: .auth)
            status = .unauthenticated
            return
        }

        if JWTHelper.isExpired(storedToken) {
            NavLog.info("bootstrapAuth: access token expired, attempting refresh", category: .auth)
            Task {
                let refreshed = await refreshAccessToken()
                if !refreshed {
                    NavLog.info("bootstrapAuth: refresh failed, showing re-auth prompt", category: .auth)
                    KeychainHelper.delete(key: tokenKey)
                    KeychainHelper.delete(key: refreshTokenKey)
                    status = .sessionExpired
                } else {
                    await refreshProfile()
                }
            }
            return
        }

        NavLog.debug("bootstrapAuth: found valid token, calling refreshProfile", category: .auth)
        token = storedToken
        APIService.shared.setAuthToken(storedToken)

        Task {
            await refreshProfile()
        }
    }

    public func ensureValidToken() async -> Bool {
        guard let currentToken = token else { return false }

        if JWTHelper.isExpired(currentToken) {
            NavLog.info("Token expired, attempting refresh", category: .auth)
            let refreshed = await refreshAccessToken()
            if !refreshed {
                NavLog.info("Token refresh failed, showing re-auth prompt", category: .auth)
                token = nil
                APIService.shared.setAuthToken(nil)
                KeychainHelper.delete(key: tokenKey)
                KeychainHelper.delete(key: refreshTokenKey)
                status = .sessionExpired
                return false
            }
            return true
        }

        // Proactively refresh if token expires within 5 minutes
        if JWTHelper.isExpired(currentToken, bufferSeconds: 300) {
            NavLog.info("Token expires within 5 minutes, refreshing proactively", category: .auth)
            Task { await refreshAccessToken() }
        }

        return true
    }

    // MARK: - Token Refresh

    /// Attempts to refresh the access token using the stored refresh token.
    /// Returns `true` if the refresh succeeded and new tokens were stored.
    @discardableResult
    public func refreshAccessToken() async -> Bool {
        guard !isRefreshingToken else {
            NavLog.debug("Token refresh already in progress, skipping", category: .auth)
            return false
        }

        guard let storedRefreshToken = KeychainHelper.load(key: refreshTokenKey) else {
            NavLog.debug("No refresh token available", category: .auth)
            return false
        }

        isRefreshingToken = true
        defer { isRefreshingToken = false }

        do {
            let response: RefreshTokenResponse = try await APIService.shared.post(
                path: "/refresh",
                body: ["refresh_token": storedRefreshToken]
            )

            let newAccessToken = response.accessToken

            if JWTHelper.decode(newAccessToken) == nil {
                NavLog.warning("Received malformed JWT from refresh endpoint", category: .auth)
                return false
            }

            KeychainHelper.save(key: tokenKey, value: newAccessToken)
            if let newRefreshToken = response.refreshToken {
                KeychainHelper.save(key: refreshTokenKey, value: newRefreshToken)
            }

            token = newAccessToken
            APIService.shared.setAuthToken(newAccessToken)
            NavLog.info("Token refresh succeeded", category: .auth)
            return true
        } catch {
            NavLog.error("Token refresh failed: \(error.localizedDescription)", category: .auth)
            return false
        }
    }

    // MARK: - OTP Auth

    public func sendOtp(phoneNumber: String) async throws {
        let query = """
        mutation SendOtp($phoneNumber: String!) {
          sendOtp(phoneNumber: $phoneNumber) {
            message
            otp
          }
        }
        """
        NavLog.debug("sendOtp called for: \(phoneNumber)", category: .auth)
        do {
            let _: SendOtpData = try await APIService.shared.graphQLCodable(
                query: query,
                variables: ["phoneNumber": phoneNumber]
            )
            NavLog.info("sendOtp succeeded", category: .auth)
        } catch {
            NavLog.error("sendOtp failed: \(error)", category: .auth)
            throw error
        }
        KeychainHelper.save(key: phoneKey, value: phoneNumber)
    }

    public func verifyOtp(phoneNumber: String, otp: String) async throws {
        let query = """
        mutation VerifyOtp($phoneNumber: String!, $otp: String!) {
          verifyOtp(phoneNumber: $phoneNumber, otp: $otp) {
            accessToken
            userId
            isNewUser
            isProfileComplete
          }
        }
        """

        NavLog.debug("verifyOtp called", category: .auth)
        let result: VerifyOtpData
        do {
            result = try await APIService.shared.graphQLCodable(
                query: query,
                variables: ["phoneNumber": phoneNumber, "otp": otp]
            )
        } catch {
            NavLog.error("verifyOtp failed: \(error)", category: .auth)
            throw error
        }

        let accessToken = result.verifyOtp.accessToken

        if JWTHelper.decode(accessToken) == nil {
            NavLog.warning("Received malformed JWT from server", category: .auth)
        }

        KeychainHelper.save(key: tokenKey, value: accessToken)
        KeychainHelper.save(key: phoneKey, value: phoneNumber)
        if let refreshToken = result.verifyOtp.refreshToken {
            KeychainHelper.save(key: refreshTokenKey, value: refreshToken)
        }
        if let uid = result.verifyOtp.userId {
            KeychainHelper.save(key: userIdKey, value: uid.value)
        }

        token = accessToken
        APIService.shared.setAuthToken(accessToken)
        await refreshProfile()
    }

    @discardableResult
    public func refreshProfile() async -> UserProfile? {
        NavLog.debug("refreshProfile called", category: .auth)
        isRefreshingProfile = true
        defer { isRefreshingProfile = false }

        let query = """
        query Me {
          me {
            id name phoneNumber age gender bio location
            interests languages lookingFor professionCategory
            professionTitle heightCm photos isProfileComplete
            isVerified isStudentVerified
          }
        }
        """

        do {
            let result: MeData = try await APIService.shared.graphQLCodable(query: query)
            guard let me = result.me else {
                NavLog.info("refreshProfile: 'me' is nil, setting unauthenticated", category: .auth)
                status = .unauthenticated
                user = nil
                return nil
            }

            let profile = UserProfile(
                id: me.id.value,
                name: me.name,
                phoneNumber: me.phoneNumber,
                age: me.age,
                gender: me.gender,
                bio: me.bio,
                location: me.location,
                professionCategory: me.professionCategory,
                professionTitle: me.professionTitle,
                interests: me.interests,
                photos: me.photos,
                isProfileComplete: me.isProfileComplete?.value,
                isVerified: me.isVerified,
                isStudentVerified: me.isStudentVerified,
                heightCm: me.heightCm,
                languages: me.languages,
                lookingFor: me.lookingFor,
                voiceIntroUrl: me.voiceIntroUrl
            )

            user = profile
            status = .authenticated
            NavLog.info("refreshProfile succeeded: \(profile.displayName)", category: .auth)
            return profile
        } catch is CancellationError {
            NavLog.debug("refreshProfile cancelled", category: .auth)
            return nil
        } catch {
            NavLog.error("refreshProfile failed: \(error)", category: .auth)
            status = .unauthenticated
            user = nil
            return nil
        }
    }

    public func logout() {
        NavLog.info("Logging out", category: .auth)
        onLogout?()
        status = .unauthenticated
        user = nil
        token = nil
        APIService.shared.setAuthToken(nil)
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: refreshTokenKey)
        KeychainHelper.delete(key: phoneKey)
        KeychainHelper.delete(key: userIdKey)
        LocalCache.shared.rotateKey()
    }

}
