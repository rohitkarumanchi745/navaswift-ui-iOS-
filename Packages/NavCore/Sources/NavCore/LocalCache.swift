import Foundation
import CryptoKit

/// Lightweight file-based cache for Codable types.
/// Stores last-good copies of feed/chat data for offline reading.
/// Data is AES-GCM encrypted at rest using a device-derived key.
/// Files are stored in the app's caches directory with automatic staleness tracking.
public final class LocalCache {
    public static let shared = LocalCache()

    private let cacheDir: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var encryptionKey: SymmetricKey

    private static let keychainAccount = "nava_cache_encryption_secret"
    /// Maximum total size of all cached files in bytes (10 MB).
    private let maxTotalBytes: Int = 10 * 1024 * 1024
    /// Maximum size of a single cached entry in bytes (2 MB).
    private let maxEntryBytes: Int = 2 * 1024 * 1024

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = base.appendingPathComponent("nava_local_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        encryptionKey = LocalCache.loadOrCreateKey()
    }

    // MARK: - Encryption Key

    /// Loads the existing encryption key from the Keychain, or generates and stores a new one.
    private static func loadOrCreateKey() -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let secretData = result as? Data, secretData.count == 32 {
            return SymmetricKey(data: secretData)
        }

        return generateAndStoreKey()
    }

    /// Generates a fresh 256-bit key and stores it in the Keychain.
    private static func generateAndStoreKey() -> SymmetricKey {
        let newSecret = SymmetricKey(size: .bits256)
        let secretData = newSecret.withUnsafeBytes { Data($0) }

        // Remove any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)

        return newSecret
    }

    /// Rotates the cache encryption key. Call on logout to ensure the next
    /// login session uses a fresh key. Old encrypted cache files become
    /// unreadable and are auto-removed on next access attempt.
    public func rotateKey() {
        clearAll()
        encryptionKey = LocalCache.generateAndStoreKey()
        NavLog.debug("Cache encryption key rotated", category: .general)
    }

    // MARK: - Public API

    /// Saves a Codable value under the given key, encrypted with AES-GCM.
    /// Enforces per-entry and total cache size limits with LRU eviction.
    public func save<T: Codable>(_ value: T, forKey key: CacheKey) {
        let wrapper = CacheWrapper(data: value, cachedAt: Date())
        do {
            let jsonData = try encoder.encode(wrapper)

            // Reject entries that exceed the per-entry size limit
            if jsonData.count > maxEntryBytes {
                NavLog.debug("LocalCache entry too large for \(key.rawValue): \(jsonData.count) bytes (max \(maxEntryBytes))", category: .general)
                return
            }

            let sealed = try AES.GCM.seal(jsonData, using: encryptionKey)
            guard let combined = sealed.combined else { return }
            let fileURL = url(for: key)
            try combined.write(to: fileURL, options: [.atomicWrite])

            evictIfNeeded()
        } catch {
            NavLog.debug("LocalCache save failed for \(key.rawValue): \(error.localizedDescription)", category: .general)
        }
    }

    /// Loads a cached value. Returns `nil` if not found or if older than `maxAge`.
    public func load<T: Codable>(_ type: T.Type, forKey key: CacheKey, maxAge: TimeInterval = 86400) -> T? {
        guard let wrapper: CacheWrapper<T> = decryptAndDecode(forKey: key) else { return nil }
        let age = Date().timeIntervalSince(wrapper.cachedAt)
        if age > maxAge {
            NavLog.debug("LocalCache stale for \(key.rawValue) (age: \(Int(age))s)", category: .general)
            return nil
        }
        return wrapper.data
    }

    /// Loads cached data regardless of age. Used as last-resort fallback when offline.
    public func loadStale<T: Codable>(_ type: T.Type, forKey key: CacheKey) -> T? {
        guard let wrapper: CacheWrapper<T> = decryptAndDecode(forKey: key) else { return nil }
        return wrapper.data
    }

    /// Removes cached data for a given key.
    public func remove(forKey key: CacheKey) {
        try? FileManager.default.removeItem(at: url(for: key))
    }

    /// Clears all cached data (e.g. on logout).
    public func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Eviction

    /// Evicts the oldest cache files when total size exceeds the budget.
    private func evictIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        var entries: [(url: URL, size: Int, modified: Date)] = files.compactMap { fileURL in
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let modified = values.contentModificationDate else { return nil }
            return (fileURL, size, modified)
        }

        var totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > maxTotalBytes else { return }

        // Sort oldest first for LRU eviction
        entries.sort { $0.modified < $1.modified }

        for entry in entries {
            guard totalSize > maxTotalBytes else { break }
            try? fm.removeItem(at: entry.url)
            totalSize -= entry.size
            NavLog.debug("LocalCache evicted \(entry.url.lastPathComponent) (\(entry.size) bytes)", category: .general)
        }
    }

    // MARK: - Internals

    private func url(for key: CacheKey) -> URL {
        cacheDir.appendingPathComponent(key.rawValue + ".enc")
    }

    private func decryptAndDecode<T: Codable>(forKey key: CacheKey) -> CacheWrapper<T>? {
        let fileURL = url(for: key)
        guard let encryptedData = try? Data(contentsOf: fileURL) else { return nil }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return try decoder.decode(CacheWrapper<T>.self, from: decryptedData)
        } catch {
            NavLog.debug("LocalCache decrypt/decode failed for \(key.rawValue): \(error.localizedDescription)", category: .general)
            // Remove corrupted file
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }
}

// MARK: - Cache Keys

public extension LocalCache {
    enum CacheKey: String {
        case discoverFeed = "discover_feed"
        case conversations = "conversations"
        case matches = "matches"
        case reelInbox = "reel_inbox"
    }
}

// MARK: - Wrapper

private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let cachedAt: Date
}
