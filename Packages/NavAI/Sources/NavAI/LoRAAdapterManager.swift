import Foundation
import CryptoKit
import NavCore
import NavAIPrompt

/// Describes a per-user LoRA adapter to fetch.
public struct LoRAAdapterSpec: Sendable, Equatable {
    public let userID: String
    public let version: Int          // bump when the server retrains
    public let remoteURL: URL
    public let sha256: String
    public let sizeBytes: Int64

    public init(userID: String, version: Int, remoteURL: URL, sha256: String, sizeBytes: Int64) {
        self.userID = userID
        self.version = version
        self.remoteURL = remoteURL
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

/// Downloads, verifies, and locates per-user LoRA adapters (small GGUF files
/// produced by the server/federated trainer). Adapters are versioned so a newer
/// one supersedes the cached copy.
@MainActor
public final class LoRAAdapterManager: ObservableObject {

    @Published public private(set) var isFetching = false
    private let fileManager = FileManager.default

    public init() {}

    /// Local path for a given user+version adapter.
    public func localURL(for spec: LoRAAdapterSpec) -> URL {
        adaptersDir().appendingPathComponent("\(spec.userID)-v\(spec.version).gguf")
    }

    /// Latest cached adapter version for a user, if any.
    public func cachedVersion(for userID: String) -> Int? {
        let prefix = "\(userID)-v"
        let files = (try? fileManager.contentsOfDirectory(atPath: adaptersDir().path)) ?? []
        return files
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".gguf") }
            .compactMap { name -> Int? in
                name.dropFirst(prefix.count).dropLast(".gguf".count).description
                    .split(separator: ".").first.flatMap { Int($0) }
            }
            .max()
    }

    /// Ensure the specified adapter is present, downloading + verifying if the
    /// cached copy is missing or an older version. Returns the local path.
    @discardableResult
    public func ensureAdapter(_ spec: LoRAAdapterSpec) async throws -> URL {
        let dest = localURL(for: spec)
        if fileManager.fileExists(atPath: dest.path) { return dest }

        isFetching = true
        defer { isFetching = false }

        let tempURL: URL
        do {
            (tempURL, _) = try await URLSession.shared.download(from: spec.remoteURL)
        } catch {
            throw OnDeviceLLMError.downloadFailed(error.localizedDescription)
        }

        let digest = try sha256(of: tempURL)
        guard digest == spec.sha256.lowercased() else {
            try? fileManager.removeItem(at: tempURL)
            throw OnDeviceLLMError.downloadFailed("adapter checksum mismatch")
        }

        try? fileManager.removeItem(at: dest)
        try fileManager.moveItem(at: tempURL, to: dest)

        // Drop older versions to reclaim space.
        pruneOldVersions(userID: spec.userID, keep: spec.version)
        NavLog.info("LoRA adapter for \(spec.userID) v\(spec.version) ready", category: .general)
        return dest
    }

    // MARK: - Helpers

    private func adaptersDir() -> URL {
        let base = (try? fileManager.url(for: .applicationSupportDirectory,
                                         in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("NavAI/adapters", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func pruneOldVersions(userID: String, keep: Int) {
        let prefix = "\(userID)-v"
        let files = (try? fileManager.contentsOfDirectory(atPath: adaptersDir().path)) ?? []
        for name in files where name.hasPrefix(prefix) && name.hasSuffix(".gguf") {
            let versionPart = name.dropFirst(prefix.count).dropLast(".gguf".count)
            if let v = Int(versionPart.split(separator: ".").first ?? ""), v != keep {
                try? fileManager.removeItem(at: adaptersDir().appendingPathComponent(name))
            }
        }
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1 << 20)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
