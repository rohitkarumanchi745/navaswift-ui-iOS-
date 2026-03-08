import SwiftUI
import Combine
import Security
import NavCore
import NavNetworking

// MARK: - Auth Status
public enum AuthStatus: Equatable, Hashable {
    case loading, unauthenticated, authenticated
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
        SecItemAdd(add as CFDictionary, nil)
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
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth Manager
@MainActor
public class AuthManager: ObservableObject {
    @Published public var status: AuthStatus = .loading
    @Published public var user: UserProfile?
    @Published public var token: String?
    @Published public var isRefreshingProfile = false

    private let tokenKey = "nava_token"
    private let phoneKey = "nava_phone"
    private let userIdKey = "nava_user_id"

    public init() {
        bootstrapAuth()
    }

    private func bootstrapAuth() {
        guard let storedToken = KeychainHelper.load(key: tokenKey),
              !storedToken.hasPrefix("mock-token"),
              !storedToken.hasPrefix("demo-token") else {
            print("[NAVA DEBUG] bootstrapAuth: no valid token, setting unauthenticated")
            status = .unauthenticated
            return
        }

        print("[NAVA DEBUG] bootstrapAuth: found token, calling refreshProfile")
        token = storedToken
        APIService.shared.setAuthToken(storedToken)

        Task {
            await refreshProfile()
        }
    }

    public func sendOtp(phoneNumber: String) async throws {
        let query = """
        mutation SendOtp($phoneNumber: String!) {
          sendOtp(phoneNumber: $phoneNumber) {
            message
            otp
          }
        }
        """
        print("[NAVA DEBUG] sendOtp called with phoneNumber: \(phoneNumber)")
        print("[NAVA DEBUG] sendOtp query: \(query)")
        print("[NAVA DEBUG] sendOtp variables: [\"phoneNumber\": \(phoneNumber)]")
        do {
            let _: [String: Any] = try await APIService.shared.graphQL(
                query: query,
                variables: ["phoneNumber": phoneNumber]
            )
            print("[NAVA DEBUG] sendOtp SUCCESS")
        } catch {
            print("[NAVA DEBUG] sendOtp FAILED: \(error)")
            throw error
        }
        UserDefaults.standard.set(phoneNumber, forKey: phoneKey)
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

        print("[NAVA DEBUG] verifyOtp called with phoneNumber: \(phoneNumber), otp: \(otp)")
        let result: [String: Any]
        do {
            result = try await APIService.shared.graphQL(
                query: query,
                variables: ["phoneNumber": phoneNumber, "otp": otp]
            )
            print("[NAVA DEBUG] verifyOtp result: \(result)")
        } catch {
            print("[NAVA DEBUG] verifyOtp FAILED: \(error)")
            throw error
        }

        guard let verifyOtp = result["verifyOtp"] as? [String: Any],
              let accessToken = verifyOtp["accessToken"] as? String else {
            print("[NAVA DEBUG] verifyOtp parse FAILED - result was: \(result)")
            throw APIError.invalidResponse
        }

        let userId = verifyOtp["userId"]

        KeychainHelper.save(key: tokenKey, value: accessToken)
        UserDefaults.standard.set(phoneNumber, forKey: phoneKey)
        if let uid = userId {
            UserDefaults.standard.set("\(uid)", forKey: userIdKey)
        }

        token = accessToken
        APIService.shared.setAuthToken(accessToken)
        await refreshProfile()
    }

    @discardableResult
    public func refreshProfile() async -> UserProfile? {
        print("[NAVA DEBUG] refreshProfile called (BUILD v2)")
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
            let result: [String: Any] = try await APIService.shared.graphQL(query: query)
            print("[NAVA DEBUG] refreshProfile result: \(result)")
            guard let me = result["me"] as? [String: Any] else {
                print("[NAVA DEBUG] refreshProfile: 'me' is nil, setting unauthenticated")
                status = .unauthenticated
                user = nil
                return nil
            }

            // Parse isProfileComplete robustly — NSNumber from JSON can be tricky
            let rawComplete = me["isProfileComplete"]
            let isComplete: Bool?
            if let boolVal = rawComplete as? Bool {
                isComplete = boolVal
            } else if let numVal = rawComplete as? NSNumber {
                isComplete = numVal.boolValue
            } else if let intVal = rawComplete as? Int {
                isComplete = intVal != 0
            } else {
                isComplete = nil
            }
            print("[NAVA DEBUG] refreshProfile: isProfileComplete raw=\(String(describing: rawComplete)) parsed=\(String(describing: isComplete))")

            let profile = UserProfile(
                id: "\(me["id"] ?? "")",
                name: me["name"] as? String,
                phoneNumber: me["phoneNumber"] as? String,
                age: me["age"] as? Int,
                gender: me["gender"] as? String,
                bio: me["bio"] as? String,
                location: me["location"] as? String,
                professionCategory: me["professionCategory"] as? String,
                professionTitle: me["professionTitle"] as? String,
                interests: me["interests"] as? [String],
                photos: me["photos"] as? [String],
                isProfileComplete: isComplete,
                isVerified: me["isVerified"] as? Bool,
                isStudentVerified: me["isStudentVerified"] as? Bool,
                heightCm: me["heightCm"] as? Int,
                languages: me["languages"] as? [String],
                lookingFor: me["lookingFor"] as? String,
                voiceIntroUrl: me["voiceIntroUrl"] as? String
            )

            user = profile
            status = .authenticated
            print("[NAVA DEBUG] refreshProfile SUCCESS - user: \(profile.displayName), isProfileComplete: \(profile.isProfileComplete ?? false), status now: \(status)")
            return profile
        } catch {
            print("[NAVA DEBUG] refreshProfile FAILED: \(error) - setting unauthenticated")
            status = .unauthenticated
            user = nil
            return nil
        }
    }

    public func logout() {
        status = .unauthenticated
        user = nil
        token = nil
        APIService.shared.setAuthToken(nil)
        KeychainHelper.delete(key: tokenKey)
        UserDefaults.standard.removeObject(forKey: phoneKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }

    // MARK: - Demo Mode (for testing without backend)
    public func loginWithDemoUser() {
        let demoUser = UserProfile(
            id: "demo-user-1",
            name: "Rohit",
            phoneNumber: "+919876543210",
            age: 27,
            gender: "Male",
            bio: "Software developer who loves building apps. Coffee enthusiast and weekend hiker.",
            location: "Hyderabad",
            professionCategory: "tech",
            professionTitle: "iOS Developer",
            interests: ["Tech", "Coffee", "Hiking", "Music", "Travel"],
            photos: ["https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80"],
            isProfileComplete: true,
            isVerified: true,
            isStudentVerified: false,
            heightCm: 178,
            languages: ["Telugu", "English", "Hindi"],
            lookingFor: "long_term"
        )
        user = demoUser
        token = "demo-token"
        status = .authenticated
    }

    public func loginWithDemoNewUser() {
        let newUser = UserProfile(
            id: "demo-user-2",
            name: nil,
            isProfileComplete: false
        )
        user = newUser
        token = "demo-token"
        status = .authenticated
    }
}
