import Foundation
import CryptoKit
import NavCore
import NavAIPrompt

/// Describes a downloadable GGUF model.
public struct BitNetModelSpec: Sendable {
    public let name: String        // file stem, e.g. "bitnet-b1.58-2B-4T-i2s"
    public let remoteURL: URL      // your CDN or Hugging Face mirror
    public let sha256: String      // lowercase hex; integrity + anti-tamper
    public let sizeBytes: Int64    // for progress when the server omits length

    public init(name: String, remoteURL: URL, sha256: String, sizeBytes: Int64) {
        self.name = name
        self.remoteURL = remoteURL
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}

/// Downloads, verifies, stores, and locates the on-device model file.
///
/// The model is intentionally NOT bundled (a 2B BitNet is ~1.1 GB) — it's
/// fetched on first use into Application Support and checksum-verified.
@MainActor
public final class BitNetModelManager: ObservableObject {

    public enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    @Published public private(set) var state: State = .notDownloaded

    public let spec: BitNetModelSpec
    private let fileManager = FileManager.default

    public init(spec: BitNetModelSpec) {
        self.spec = spec
        if fileManager.fileExists(atPath: localURL.path) {
            state = .ready
        }
    }

    /// Final on-disk location of the model.
    public var localURL: URL {
        let base = (try? fileManager.url(for: .applicationSupportDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("NavAI/models", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(spec.name).gguf")
    }

    public var isModelAvailable: Bool {
        fileManager.fileExists(atPath: localURL.path)
    }

    /// Ensure the model is present (downloading + verifying if needed). Idempotent.
    @discardableResult
    public func ensureModel() async throws -> URL {
        if isModelAvailable {
            state = .ready
            return localURL
        }
        return try await download()
    }

    /// Delete the local model (e.g. to reclaim space).
    public func removeModel() {
        try? fileManager.removeItem(at: localURL)
        state = .notDownloaded
    }

    // MARK: - Download

    private func download() async throws -> URL {
        state = .downloading(progress: 0)
        NavLog.info("Downloading BitNet model \(spec.name)", category: .general)

        let delegate = DownloadProgressDelegate { [weak self] fraction in
            Task { @MainActor in self?.state = .downloading(progress: fraction) }
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let tempURL: URL
        do {
            (tempURL, _) = try await session.download(from: spec.remoteURL, delegate: delegate)
        } catch {
            state = .failed(error.localizedDescription)
            throw OnDeviceLLMError.downloadFailed(error.localizedDescription)
        }

        // Integrity check before we trust the file.
        let digest = try sha256(of: tempURL)
        guard digest == spec.sha256.lowercased() else {
            try? fileManager.removeItem(at: tempURL)
            state = .failed("checksum mismatch")
            NavLog.error("BitNet model checksum mismatch (\(digest) != \(spec.sha256))", category: .general)
            throw OnDeviceLLMError.downloadFailed("checksum mismatch")
        }

        // Atomically place it at the final location.
        try? fileManager.removeItem(at: localURL)
        do {
            try fileManager.moveItem(at: tempURL, to: localURL)
        } catch {
            state = .failed(error.localizedDescription)
            throw OnDeviceLLMError.downloadFailed(error.localizedDescription)
        }

        state = .ready
        NavLog.info("BitNet model \(spec.name) ready", category: .general)
        return localURL
    }

    /// Streaming SHA-256 so we never load ~1 GB into memory.
    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1 << 20) // 1 MB
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Reports byte-level download progress.
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    // Required by the protocol; the async `download(from:delegate:)` handles the
    // moved file for us, so nothing to do here.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}
}
