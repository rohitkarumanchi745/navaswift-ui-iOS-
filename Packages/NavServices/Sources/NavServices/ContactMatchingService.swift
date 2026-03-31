import Foundation
import Contacts
import CryptoKit
import NavCore
import NavNetworking

@MainActor
public class ContactMatchingService: ObservableObject {

    // MARK: - Published State

    @Published public var friends: [ContactSyncResponse.ContactFriend] = []
    @Published public var isSyncing = false
    @Published public var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined

    // MARK: - Throttling

    private let lastSyncKey = "contacts_last_sync"
    private let syncIntervalSeconds: TimeInterval = 86400

    // MARK: - Init

    public init() {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        if let cached = LocalCache.shared.load(ContactSyncResponse.self, forKey: .contactFriends) {
            friends = cached.friends
        }
    }

    // MARK: - Request Permission + Sync

    /// Requests Contacts permission if not yet determined, then syncs if authorized.
    public func requestAndSync() async {
        let store = CNContactStore()

        if contactsPermissionStatus == .notDetermined {
            do {
                let granted = try await store.requestAccess(for: .contacts)
                contactsPermissionStatus = granted ? .authorized : .denied
            } catch {
                NavLog.warning("Contacts permission request failed: \(error.localizedDescription)", category: .general)
                contactsPermissionStatus = .denied
                return
            }
        } else {
            contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        }

        guard contactsPermissionStatus == .authorized else {
            NavLog.debug("Contacts not authorized, skipping sync", category: .general)
            return
        }

        await syncContacts(store: store)
    }

    /// Syncs contacts if authorized and enough time has passed since last sync.
    public func syncIfNeeded() async {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        guard contactsPermissionStatus == .authorized else { return }
        guard shouldSync() else {
            NavLog.debug("Contacts sync skipped — last sync was recent", category: .general)
            return
        }
        await syncContacts(store: CNContactStore())
    }

    // MARK: - Core Sync Logic

    private func syncContacts(store: CNContactStore) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let keysToFetch = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)

            var phoneNumbers: [String] = []
            try store.enumerateContacts(with: request) { contact, _ in
                for phone in contact.phoneNumbers {
                    let normalized = Self.normalizePhoneNumber(phone.value.stringValue)
                    if !normalized.isEmpty {
                        phoneNumbers.append(normalized)
                    }
                }
            }

            // Hash with SHA256
            let hashed = phoneNumbers.map { number in
                let data = Data(number.utf8)
                let hash = SHA256.hash(data: data)
                return hash.map { String(format: "%02x", $0) }.joined()
            }

            guard !hashed.isEmpty else {
                NavLog.debug("No phone numbers to sync", category: .general)
                return
            }

            let response: ContactSyncResponse = try await APIService.shared.post(
                path: "/contacts/sync",
                body: ["hashed_phone_numbers": hashed]
            )

            friends = response.friends
            LocalCache.shared.save(response, forKey: .contactFriends)
            markSynced()

            NavLog.info("Contacts synced: \(hashed.count) numbers, \(response.friends.count) friends found", category: .general)
        } catch {
            NavLog.warning("Contacts sync failed: \(error.localizedDescription)", category: .network)
            if friends.isEmpty,
               let cached = LocalCache.shared.loadStale(ContactSyncResponse.self, forKey: .contactFriends) {
                friends = cached.friends
            }
        }
    }

    // MARK: - Phone Number Normalization

    /// Strips spaces, dashes, parentheses. Keeps leading '+' for international format.
    static func normalizePhoneNumber(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        return digits
    }

    // MARK: - Throttle

    private func shouldSync() -> Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastSync) >= syncIntervalSeconds
    }

    private func markSynced() {
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
    }
}
