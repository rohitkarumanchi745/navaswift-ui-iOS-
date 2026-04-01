import Foundation
import CryptoKit
import NavCore

/// Provides encrypted, per-conversation message caching and an offline send queue
/// that survives app termination. Uses its own directory (`nava_messages`) separate
/// from the main LocalCache budget, and shares the same AES-GCM keychain key.
@MainActor
public final class MessageCacheService {
    public static let shared = MessageCacheService()

    private let baseDir: URL
    private let encryptionKey: SymmetricKey
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Maximum messages stored per conversation.
    private let maxMessagesPerChat = 200

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        baseDir = caches.appendingPathComponent("nava_messages", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        encryptionKey = LocalCache.sharedEncryptionKey()
    }

    // MARK: - Per-Conversation Message Cache

    /// Loads cached messages for a conversation. Returns empty array if none cached.
    public func loadMessages(matchId: String) -> [ChatMessage] {
        let url = chatFileURL(matchId: matchId)
        return decryptAndDecode([ChatMessage].self, from: url) ?? []
    }

    /// Saves messages for a conversation, capping at the most recent 200.
    public func saveMessages(_ messages: [ChatMessage], matchId: String) {
        let capped = Array(messages.suffix(maxMessagesPerChat))
        encryptAndSave(capped, to: chatFileURL(matchId: matchId))
    }

    /// Appends a single message to the cached conversation.
    public func appendMessage(_ message: ChatMessage, matchId: String) {
        var existing = loadMessages(matchId: matchId)
        guard !existing.contains(where: { $0.id == message.id }) else { return }
        existing.append(message)
        saveMessages(existing, matchId: matchId)
    }

    // MARK: - Pending Send Queue

    /// Queues a message for later sending. Persisted to disk.
    public func queuePendingMessage(_ message: ChatMessage) {
        var pending = loadAllPending()
        pending.append(message)
        encryptAndSave(pending, to: pendingFileURL)
    }

    /// Returns pending messages for a specific conversation.
    public func loadPendingMessages(matchId: String) -> [ChatMessage] {
        return loadAllPending().filter { $0.matchId == matchId }
    }

    /// Returns all pending messages across all conversations.
    public func allPendingMessages() -> [ChatMessage] {
        return loadAllPending()
    }

    /// Removes a pending message by ID after it's been sent successfully.
    public func removePending(id: String) {
        var pending = loadAllPending()
        pending.removeAll { $0.id == id }
        if pending.isEmpty {
            try? FileManager.default.removeItem(at: pendingFileURL)
        } else {
            encryptAndSave(pending, to: pendingFileURL)
        }
    }

    // MARK: - Reel Thread Cache

    /// Loads a cached reel conversation thread.
    public func loadReelThread(reelId: String, otherUserId: String) -> [ReelThreadMessage]? {
        let url = reelFileURL(reelId: reelId, otherUserId: otherUserId)
        return decryptAndDecode([ReelThreadMessage].self, from: url)
    }

    /// Saves a reel conversation thread to cache.
    public func saveReelThread(_ messages: [ReelThreadMessage], reelId: String, otherUserId: String) {
        let url = reelFileURL(reelId: reelId, otherUserId: otherUserId)
        encryptAndSave(messages, to: url)
    }

    // MARK: - Delta Sync Helpers

    /// Returns the `createdAt` of the newest cached message for a conversation,
    /// formatted as an ISO 8601 string suitable for the `since` query parameter.
    /// Returns `nil` if there are no cached messages.
    public func latestMessageISO(matchId: String) -> String? {
        let msgs = loadMessages(matchId: matchId)
        guard let latest = msgs.compactMap(\.createdAt).max() else { return nil }
        return Self.iso8601Formatter.string(from: latest)
    }

    /// Returns the `createdAt` of the newest cached reel thread message as ISO 8601.
    public func latestReelMessageISO(reelId: String, otherUserId: String) -> String? {
        guard let msgs = loadReelThread(reelId: reelId, otherUserId: otherUserId),
              let latest = msgs.compactMap({ Self.iso8601Formatter.date(from: $0.createdAt) }).max()
        else { return nil }
        return Self.iso8601Formatter.string(from: latest)
    }

    /// Merges new messages into the cached set, deduplicating by ID.
    public func mergeMessages(_ newMessages: [ChatMessage], matchId: String) {
        var existing = loadMessages(matchId: matchId)
        let existingIds = Set(existing.map(\.id))
        let unique = newMessages.filter { !existingIds.contains($0.id) }
        existing.append(contentsOf: unique)
        existing.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        saveMessages(existing, matchId: matchId)
    }

    /// Merges new reel messages into the cached thread, deduplicating by ID.
    public func mergeReelThread(_ newMessages: [ReelThreadMessage], reelId: String, otherUserId: String) {
        var existing = loadReelThread(reelId: reelId, otherUserId: otherUserId) ?? []
        let existingIds = Set(existing.map(\.id))
        let unique = newMessages.filter { !existingIds.contains($0.id) }
        existing.append(contentsOf: unique)
        // Sort by createdAt string (ISO 8601 sorts lexicographically)
        existing.sort { $0.createdAt < $1.createdAt }
        saveReelThread(existing, reelId: reelId, otherUserId: otherUserId)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Returns the last time messages were fetched for a conversation.
    public func lastFetchTimestamp(matchId: String) -> Date? {
        let meta = loadMeta()
        return meta[matchId]
    }

    /// Records when messages were last fetched for a conversation.
    public func setLastFetchTimestamp(_ date: Date, matchId: String) {
        var meta = loadMeta()
        meta[matchId] = date
        encryptAndSave(meta, to: metaFileURL)
    }

    // MARK: - Cleanup

    /// Clears all cached messages and pending sends. Called on logout.
    public func clearAll() {
        try? FileManager.default.removeItem(at: baseDir)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        NavLog.debug("MessageCacheService: cleared all data", category: .general)
    }

    // MARK: - File URLs

    private func chatFileURL(matchId: String) -> URL {
        baseDir.appendingPathComponent("chat_\(matchId).enc")
    }

    private var pendingFileURL: URL {
        baseDir.appendingPathComponent("pending_messages.enc")
    }

    private func reelFileURL(reelId: String, otherUserId: String) -> URL {
        baseDir.appendingPathComponent("reel_\(reelId)_\(otherUserId).enc")
    }

    private var metaFileURL: URL {
        baseDir.appendingPathComponent("meta.enc")
    }

    // MARK: - Encryption Helpers

    private func encryptAndSave<T: Codable>(_ value: T, to url: URL) {
        do {
            let jsonData = try encoder.encode(value)
            let sealed = try AES.GCM.seal(jsonData, using: encryptionKey)
            guard let combined = sealed.combined else { return }
            try combined.write(to: url, options: [.atomicWrite])
        } catch {
            NavLog.debug("MessageCacheService: save failed — \(error.localizedDescription)", category: .general)
        }
    }

    private func decryptAndDecode<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        guard let encryptedData = try? Data(contentsOf: url) else { return nil }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return try decoder.decode(T.self, from: decryptedData)
        } catch {
            NavLog.debug("MessageCacheService: decrypt/decode failed — \(error.localizedDescription)", category: .general)
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Internal Helpers

    private func loadAllPending() -> [ChatMessage] {
        return decryptAndDecode([ChatMessage].self, from: pendingFileURL) ?? []
    }

    private func loadMeta() -> [String: Date] {
        return decryptAndDecode([String: Date].self, from: metaFileURL) ?? [:]
    }
}
