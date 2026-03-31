import Foundation
import UIKit
import SwiftUI
import AVFoundation
import NavCore
import NavNetworking

// MARK: - Upload Phase

public enum ReelUploadPhase: Equatable {
    case idle
    case compressing(progress: Double)
    case awaitingFilter
    case exportingFilter(progress: Double)
    case readyToPost
    case mixingAudio(progress: Double)
    case uploading(progress: Double)
    case done(reelId: Int)
    case failed(message: String)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.awaitingFilter, .awaitingFilter), (.readyToPost, .readyToPost):
            return true
        case (.compressing(let a), .compressing(let b)):
            return a == b
        case (.exportingFilter(let a), .exportingFilter(let b)):
            return a == b
        case (.mixingAudio(let a), .mixingAudio(let b)):
            return a == b
        case (.uploading(let a), .uploading(let b)):
            return a == b
        case (.done(let a), .done(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }

    public var isActive: Bool {
        switch self {
        case .compressing, .awaitingFilter, .exportingFilter, .readyToPost, .mixingAudio, .uploading:
            return true
        default:
            return false
        }
    }

    /// Unified 0.0–1.0 progress across the entire post pipeline (Instagram-style single bar).
    /// Phases after the user taps "Post": mixAudio(15%) → compress(15%) → upload(70%)
    public var progress: Double {
        switch self {
        case .mixingAudio(let p):      return p * 0.15
        case .compressing(let p):      return 0.15 + p * 0.15
        case .awaitingFilter:          return 0.15
        case .exportingFilter(let p):  return 0.15 + p * 0.2
        case .readyToPost:             return 0.35
        case .uploading(let p):        return 0.30 + p * 0.70
        case .done:                    return 1.0
        default:                       return 0.0
        }
    }

    /// User-facing label — single simple status like Instagram ("Posting...")
    public var statusLabel: String {
        switch self {
        case .idle:                    return ""
        case .compressing:             return "Posting..."
        case .awaitingFilter:          return "Pick a filter"
        case .exportingFilter:         return "Applying filter..."
        case .readyToPost:             return "Ready to post"
        case .mixingAudio:             return "Posting..."
        case .uploading:               return "Posting..."
        case .done:                    return "Shared"
        case .failed:                  return "Failed — tap to retry"
        }
    }
}

// MARK: - ReelUploadService

@MainActor
public class ReelUploadService: ObservableObject {
    public static let shared = ReelUploadService()

    @Published public var phase: ReelUploadPhase = .idle
    @Published public var thumbnail: UIImage?
    @Published public var selectedFilter: VideoFilter = .original

    /// Notification posted when upload finishes so views can refresh.
    public static let didFinishUploadNotification = Notification.Name("ReelUploadDidFinish")

    /// The best available video URL for preview playback (filtered > compressed).
    public var previewVideoURL: URL? { filteredURL ?? compressedURL }

    // Internal pipeline state
    private var compressedURL: URL?
    private var filteredURL: URL?
    private var compressionTask: Task<URL, Error>?
    private var filterExportTask: Task<Void, Error>?
    private var currentExportSession: AVAssetExportSession?

    // Retry state — stores last post() parameters
    private var lastPostCaption: String?
    private var lastPostScope: String?
    private var lastPostMusic: ReelMusic?
    private var lastPostMusicVolume: Float?
    private var lastPostLocation: String?
    private var lastPostLatitude: Double?
    private var lastPostLongitude: Double?
    private var lastPostAuthToken: String?

    // Background execution — keeps the app alive during mix/compress/upload
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Upload session — plain foreground session (no delegate).
    // Progress is tracked by polling the URLSessionTask directly instead of
    // using a delegate + CheckedContinuation, which caused continuation leaks
    // when the retry loop overwrote the delegate's continuation reference.
    private lazy var uploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// Max automatic retries for transient network errors before showing failure.
    private static let maxAutoRetries = 3

    // Temp file for the multipart body — kept across retries, cleaned on success/reset.
    private var pendingUploadFile: URL?

    // Progress polling task — cancelled before transitioning away from .uploading
    private var activeProgressPoller: Task<Void, Never>?

    public init() {}

    // MARK: - Background Task Helpers

    private func beginBackgroundProcessing() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ReelUpload") { [weak self] in
            NavLog.warning("Reel upload: background time expiring", category: .general)
            Task { @MainActor in
                // Mark as failed so the pill doesn't stay stuck at "Posting..." forever
                if let self, self.phase.isActive {
                    self.phase = .failed(message: "Upload interrupted — tap to retry")
                }
            }
            self?.endBackgroundProcessing()
        }
        NavLog.info("Reel upload: background task started (id=\(backgroundTaskID.rawValue))", category: .general)
    }

    private func endBackgroundProcessing() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        NavLog.info("Reel upload: background task ended", category: .general)
        backgroundTaskID = .invalid
    }

    // MARK: - Step 1: Prepare (called immediately on video pick)

    /// Copies the source video to a stable temp location and extracts a thumbnail.
    /// No re-encoding is performed — the original resolution (4K, 1080p, etc.) is preserved.
    public func prepare(localURL: URL) {
        reset()

        // Fast path: if source is already in temp (e.g. from PhotosPicker / trimmer),
        // skip the detached copy task and set state synchronously for instant UI.
        let sourcePath = localURL.path
        let tempDir = FileManager.default.temporaryDirectory.path
        if sourcePath.hasPrefix(tempDir) {
            compressedURL = localURL
            phase = .awaitingFilter
            NavLog.info("Prepare: using source directly (already in temp)", category: .general)

            // Wrap in an already-completed task so applyFilter can still await it
            compressionTask = Task { localURL }
        } else {
            phase = .compressing(progress: 0)

            // Copy source to a stable temp path (no re-encoding, preserves full quality)
            compressionTask = Task.detached { [weak self] in
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("source_\(UUID().uuidString).mp4")

                do {
                    try FileManager.default.copyItem(at: localURL, to: outputURL)
                } catch {
                    throw VideoFilterError.compressionFailed("Failed to copy video: \(error.localizedDescription)")
                }

                await MainActor.run {
                    self?.compressedURL = outputURL
                    self?.phase = .awaitingFilter
                }

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                NavLog.info("Prepare: source copied (\(fileSize / 1024)KB), full quality preserved", category: .general)
                return outputURL
            }
        }

        // Extract thumbnail in background
        Task {
            let thumb = await Self.extractThumbnail(from: localURL)
            self.thumbnail = thumb
        }
    }

    // MARK: - Step 2: Apply Filter

    /// Called when user taps a filter swatch. Cancels any previous export, starts new one.
    /// Sets phase to `.readyToPost` when the filtered file is ready.
    public func applyFilter(_ filter: VideoFilter) {
        // Cancel previous filter export
        filterExportTask?.cancel()
        currentExportSession?.cancelExport()
        selectedFilter = filter

        filterExportTask = Task { [weak self] in
            guard let self else { return }

            // Wait for compression to finish if still running
            let compressed: URL
            do {
                guard let url = try await self.compressionTask?.value else {
                    await MainActor.run { self.phase = .failed(message: "No video to process") }
                    return
                }
                compressed = url
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { self.phase = .failed(message: error.localizedDescription) }
                return
            }

            try Task.checkCancellation()

            if filter == .original {
                // No filter export needed — use compressed file directly
                await MainActor.run {
                    self.filteredURL = compressed
                    self.phase = .readyToPost
                }
                return
            }

            // Start filter export
            await MainActor.run {
                self.phase = .exportingFilter(progress: 0)
            }

            do {
                let outputURL = try await filter.exportVideo(from: compressed) { progress in
                    Task { @MainActor [weak self] in
                        self?.phase = .exportingFilter(progress: progress)
                    }
                }

                try Task.checkCancellation()

                await MainActor.run {
                    self.filteredURL = outputURL
                    self.phase = .readyToPost
                }

                NavLog.info("Filter export complete: \(filter.rawValue)", category: .general)
            } catch is CancellationError {
                // Silently ignore — user switched filters
                return
            } catch let error as VideoFilterError {
                if case .cancelled = error { return }
                await MainActor.run {
                    self.phase = .failed(message: error.localizedDescription)
                }
                return
            } catch {
                await MainActor.run {
                    self.phase = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Step 3: Post (upload with caption)

    /// Called when user taps Post. Uploads the filtered video with the caption.
    /// - Parameters:
    ///   - caption: The reel caption text.
    ///   - scope: "global" or "local" — determines feed visibility.
    ///   - authToken: Bearer token for the API.
    public func post(caption: String, scope: String = "global", music: ReelMusic? = nil, musicVolume: Float = 0.5, location: String? = nil, latitude: Double? = nil, longitude: Double? = nil, authToken: String?) {
        // Store params for retry
        lastPostCaption = caption
        lastPostScope = scope
        lastPostMusic = music
        lastPostMusicVolume = musicVolume
        lastPostLocation = location
        lastPostLatitude = latitude
        lastPostLongitude = longitude
        lastPostAuthToken = authToken

        guard let videoURL = filteredURL else {
            NavLog.error("Reel upload: no filtered video URL available", category: .network)
            phase = .failed(message: "No video to upload. Please try again.")
            return
        }

        // Check disk space before creating multipart file (~2x video size needed)
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64,
           let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attrs[.systemFreeSize] as? Int64,
           freeSpace < fileSize * 2 {
            phase = .failed(message: "Not enough storage space. Free up some space and try again.")
            return
        }

        Task {
            do {
                var uploadVideoURL = videoURL

                // Mix music audio into video (re-encodes at source resolution to apply volume levels)
                if let music, let previewURLString = music.previewURL,
                   let previewURL = URL(string: previewURLString) {
                    phase = .mixingAudio(progress: 0)
                    uploadVideoURL = try await mixAudioIntoVideo(
                        videoURL: uploadVideoURL,
                        musicURL: previewURL,
                        musicVolume: musicVolume,
                        videoVolume: 1.0 - musicVolume,
                        musicStartSeconds: Double(music.startMs ?? 0) / 1000.0
                    )
                }

                // Smart compression: skip entirely when the file already fits
                // under limit; otherwise progressively downscale until it does.
                let preUploadSize = (try? FileManager.default.attributesOfItem(atPath: uploadVideoURL.path)[.size] as? Int64) ?? 0
                if preUploadSize > Self.maxUploadBytes {
                    phase = .compressing(progress: 0)
                    uploadVideoURL = try await compressForUpload(videoURL: uploadVideoURL)
                } else {
                    NavLog.info("Post: \(preUploadSize / 1024)KB is under limit — skipping compression", category: .general)
                }

                // Request background time right before the network upload begins
                // (not earlier — mix/compress happen in the foreground and don't need it)
                self.beginBackgroundProcessing()

                phase = .uploading(progress: 0)

                // Build the multipart body file (kept for retries — only cleaned on success/reset)
                let boundary = UUID().uuidString
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent("reel_upload_\(UUID().uuidString).tmp")

                try buildMultipartFile(
                    at: tempFile,
                    boundary: boundary,
                    videoURL: uploadVideoURL,
                    caption: caption,
                    scope: scope,
                    music: music,
                    location: location,
                    latitude: latitude,
                    longitude: longitude
                )
                pendingUploadFile = tempFile

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempFile.path)[.size] as? Int64) ?? 0
                NavLog.info("Reel upload: multipart file built (\(fileSize / 1024)KB)", category: .network)

                let baseURL = AppConfig.shared.apiBaseURL
                guard let url = URL(string: "\(baseURL)/reels") else {
                    phase = .failed(message: "Invalid upload URL")
                    endBackgroundProcessing()
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(
                    "multipart/form-data; boundary=\(boundary)",
                    forHTTPHeaderField: "Content-Type"
                )
                if let token = authToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                } else {
                    NavLog.error("Reel upload: NO auth token available", category: .network)
                }

                // Instagram-style: retry up to 3 times on transient network errors
                // with exponential backoff (2s, 4s, 8s) before showing failure.
                var lastError: Error?
                for attempt in 0..<Self.maxAutoRetries {
                    do {
                        if attempt > 0 {
                            let delay = pow(2.0, Double(attempt))
                            NavLog.info("Reel upload: retry #\(attempt) in \(Int(delay))s…", category: .network)
                            phase = .uploading(progress: 0)
                            try await Task.sleep(for: .seconds(delay))
                        }

                        let (data, response) = try await uploadWithProgress(
                            request: request,
                            fileURL: tempFile,
                            totalSize: fileSize
                        )

                        guard let httpResponse = response as? HTTPURLResponse else {
                            phase = .failed(message: "Invalid server response")
                            endBackgroundProcessing()
                            return
                        }

                        let body = String(data: data, encoding: .utf8) ?? ""
                        NavLog.info("Reel upload: response \(httpResponse.statusCode)", category: .network)

                        // Server errors (5xx) are retryable; client errors (4xx) are not
                        if httpResponse.statusCode >= 500 {
                            lastError = URLError(.badServerResponse)
                            NavLog.warning("Reel upload: server error \(httpResponse.statusCode), will retry", category: .network)
                            continue
                        }

                        if httpResponse.statusCode >= 400 {
                            NavLog.error("Reel upload failed (\(httpResponse.statusCode)): \(body)", category: .network)
                            phase = .failed(message: "Upload failed (status \(httpResponse.statusCode))")
                            endBackgroundProcessing()
                            return
                        }

                        // Success — stop progress polling and clean up temp file
                        activeProgressPoller?.cancel()
                        activeProgressPoller = nil
                        cleanUpPendingUpload()

                        struct UploadResponse: Codable {
                            let reel_id: Int?
                            let message: String?
                        }

                        if let result = try? JSONDecoder().decode(UploadResponse.self, from: data) {
                            let reelId = result.reel_id ?? 0
                            NavLog.info("Reel upload success: reel_id=\(reelId)", category: .network)
                            phase = .done(reelId: reelId)
                        } else {
                            NavLog.info("Reel upload: 2xx but unexpected body: \(body)", category: .network)
                            phase = .done(reelId: 0)
                        }

                        NotificationCenter.default.post(name: Self.didFinishUploadNotification, object: nil)

                        // Auto-dismiss after 3 seconds
                        try? await Task.sleep(for: .seconds(3))
                        if case .done = phase { reset() }
                        endBackgroundProcessing()
                        return

                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        lastError = error
                        let isRetryable = Self.isRetryableError(error)
                        NavLog.warning("Reel upload: attempt \(attempt + 1) failed — \(error.localizedDescription) (retryable=\(isRetryable))", category: .network)
                        if !isRetryable { break }
                    }
                }

                // All retries exhausted — stop progress polling
                activeProgressPoller?.cancel()
                activeProgressPoller = nil
                let msg = Self.userMessage(for: lastError)
                phase = .failed(message: msg)
                endBackgroundProcessing()

            } catch is CancellationError {
                NavLog.info("Reel upload cancelled", category: .network)
                reset()
                endBackgroundProcessing()
            } catch {
                NavLog.error("Reel upload error: \(error)", category: .network)
                phase = .failed(message: error.localizedDescription)
                endBackgroundProcessing()
            }
        }
    }

    // MARK: - Error Helpers

    /// Returns true for transient network errors that are worth retrying.
    private static func isRetryableError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .notConnectedToInternet,
             .networkConnectionLost, .dnsLookupFailed, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    /// Maps an error to a user-friendly message.
    private static func userMessage(for error: Error?) -> String {
        guard let urlError = error as? URLError else {
            return error?.localizedDescription ?? "Upload failed — tap to retry"
        }
        switch urlError.code {
        case .timedOut:
            return "Upload timed out. Try a shorter video or better connection."
        case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost:
            return "No connection — tap to retry"
        default:
            return "Network error — tap to retry"
        }
    }

    /// Removes the pending multipart temp file.
    private func cleanUpPendingUpload() {
        if let file = pendingUploadFile {
            try? FileManager.default.removeItem(at: file)
            pendingUploadFile = nil
        }
    }

    // MARK: - Retry

    /// Whether a retry is possible (failed state with saved params and video still available).
    public var canRetry: Bool {
        if case .failed = phase, filteredURL != nil, lastPostCaption != nil {
            return true
        }
        return false
    }

    /// Re-runs the last post() call with the same parameters.
    public func retry() {
        guard canRetry,
              let caption = lastPostCaption,
              let scope = lastPostScope else { return }
        post(
            caption: caption,
            scope: scope,
            music: lastPostMusic,
            musicVolume: lastPostMusicVolume ?? 0.5,
            location: lastPostLocation,
            latitude: lastPostLatitude,
            longitude: lastPostLongitude,
            authToken: lastPostAuthToken
        )
    }

    // MARK: - Dismiss / Reset

    public func dismiss() {
        compressionTask?.cancel()
        filterExportTask?.cancel()
        currentExportSession?.cancelExport()
        reset()
    }

    private func reset() {
        phase = .idle
        thumbnail = nil
        selectedFilter = .original
        compressedURL = nil
        filteredURL = nil
        compressionTask = nil
        filterExportTask = nil
        currentExportSession = nil
        lastPostCaption = nil
        lastPostScope = nil
        lastPostMusic = nil
        lastPostMusicVolume = nil
        lastPostLocation = nil
        lastPostLatitude = nil
        lastPostLongitude = nil
        lastPostAuthToken = nil
        activeProgressPoller?.cancel()
        activeProgressPoller = nil
        cleanUpPendingUpload()
    }

    // MARK: - Smart Compression (progressive downscale if over limit)

    private static let maxUploadBytes: Int64 = 100 * 1024 * 1024 // 100 MB — preserves video quality; NGINX allows 200MB

    /// Resolution presets to try in descending order.
    /// Each entry is (label for logging, AVAssetExportSession preset name).
    private static let resolutionLadder: [(String, String)] = [
        ("2160p", AVAssetExportPreset3840x2160),
        ("1080p", AVAssetExportPreset1920x1080),
        ("720p",  AVAssetExportPreset1280x720),
        ("540p",  AVAssetExportPreset960x540),
        ("480p",  AVAssetExportPreset640x480),
    ]

    /// Checks the file size of `videoURL`. If it's under limit, returns it unchanged.
    /// Otherwise re-exports at progressively lower resolutions until it fits.
    private func compressForUpload(videoURL: URL) async throws -> URL {
        let attrs = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0

        if fileSize <= Self.maxUploadBytes {
            NavLog.info("Compress: \(fileSize / 1024)KB is under limit — no re-encode needed", category: .general)
            return videoURL
        }

        NavLog.info("Compress: \(fileSize / 1024)KB exceeds limit — starting progressive downscale", category: .general)

        let asset = AVURLAsset(url: videoURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)

        // Detect the source video's actual resolution so we skip presets above it
        // (e.g. after a 1080p audio mix, skip 2160p to avoid a pointless re-encode).
        let sourceHeight: Int = await {
            guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return 0 }
            let size = try? await track.load(.naturalSize)
            let transform = try? await track.load(.preferredTransform)
            guard let size, let transform else { return 0 }
            let transformed = size.applying(transform)
            return Int(max(abs(transformed.width), abs(transformed.height)))
        }()
        NavLog.info("Compress: source height = \(sourceHeight)px", category: .general)

        // Map preset names to their target height for filtering
        let presetHeights: [String: Int] = [
            AVAssetExportPreset3840x2160: 2160,
            AVAssetExportPreset1920x1080: 1080,
            AVAssetExportPreset1280x720:  720,
            AVAssetExportPreset960x540:   540,
            AVAssetExportPreset640x480:   480,
        ]

        // Deduplicate presets while preserving order, skip presets above source resolution
        var seen = Set<String>()
        let uniquePresets = Self.resolutionLadder.filter { entry in
            let (_, preset) = entry
            guard seen.insert(preset).inserted && compatiblePresets.contains(preset) else { return false }
            // Skip presets whose target height exceeds the source (would upscale or waste time)
            if sourceHeight > 0, let targetH = presetHeights[preset], targetH > sourceHeight { return false }
            return true
        }

        for (label, preset) in uniquePresets {
            try Task.checkCancellation()

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("compress_\(label)_\(UUID().uuidString).mp4")

            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                continue
            }

            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            session.fileLengthLimit = Self.maxUploadBytes

            NavLog.info("Compress: trying \(label) (\(preset))…", category: .general)

            // Track progress
            let progressTask = Task.detached { [weak self] in
                while !Task.isCancelled {
                    let p = Double(session.progress)
                    await MainActor.run {
                        self?.phase = .compressing(progress: p)
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }

            await session.export()
            progressTask.cancel()

            guard session.status == .completed else {
                NavLog.warning("Compress: \(label) export failed, trying next", category: .general)
                try? FileManager.default.removeItem(at: outputURL)
                continue
            }

            let outSize = ((try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0)
            NavLog.info("Compress: \(label) produced \(outSize / 1024)KB", category: .general)

            if outSize <= Self.maxUploadBytes {
                NavLog.info("Compress: \(label) fits under limit ✓", category: .general)
                return outputURL
            }

            // Still too large — clean up and try the next lower resolution
            try? FileManager.default.removeItem(at: outputURL)
        }

        // If nothing fits (very unlikely), return the lowest-quality export or the original
        NavLog.warning("Compress: all presets still over limit — uploading lowest quality available", category: .general)

        // Last resort: try LowQuality one more time and accept whatever size it produces
        let fallbackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compress_fallback_\(UUID().uuidString).mp4")
        if let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality) {
            session.outputURL = fallbackURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            await session.export()
            if session.status == .completed {
                return fallbackURL
            }
        }

        // Absolute fallback — return original and let the server decide
        return videoURL
    }

    // MARK: - Audio Mixing

    /// Downloads the music preview and mixes it into the video file using AVMutableComposition.
    /// Returns the URL of the new video with music baked in.
    /// - Parameter musicStartSeconds: The offset in seconds to start playing the music from.
    private func mixAudioIntoVideo(
        videoURL: URL,
        musicURL: URL,
        musicVolume: Float,
        videoVolume: Float,
        musicStartSeconds: Double = 0
    ) async throws -> URL {
        NavLog.info("Audio mix: downloading music preview…", category: .general)

        // 1. Download the music preview to a local temp file
        let audioLocalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("music_preview_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: audioLocalURL)

        // Download the music preview file in one shot.
        // The previous byte-by-byte async stream caused extreme CPU usage/heat
        // by iterating millions of times and dispatching to MainActor on each byte.
        let (tempDownloadURL, _) = try await URLSession.shared.download(from: musicURL)

        // Move the downloaded temp file to our known location
        try? FileManager.default.removeItem(at: audioLocalURL)
        try FileManager.default.moveItem(at: tempDownloadURL, to: audioLocalURL)
        await MainActor.run { [weak self] in self?.phase = .mixingAudio(progress: 0.2) }

        let downloadSize = ((try? FileManager.default.attributesOfItem(atPath: audioLocalURL.path)[.size] as? Int64) ?? 0)
        NavLog.info("Audio mix: preview downloaded (\(downloadSize / 1024)KB), building composition…", category: .general)

        // 2. Load assets
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioLocalURL)

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)

        // 3. Create composition
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                  withMediaType: .video,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            NavLog.warning("Audio mix: no video track found, skipping mix", category: .general)
            try? FileManager.default.removeItem(at: audioLocalURL)
            return videoURL
        }

        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )

        // Preserve the video's preferred transform (orientation)
        compositionVideoTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

        // Add original video audio track (if exists)
        let videoAudioTracks = try await videoAsset.loadTracks(withMediaType: .audio)
        var compositionVideoAudioTrack: AVMutableCompositionTrack?
        if let originalAudioTrack = videoAudioTracks.first {
            compositionVideoAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try compositionVideoAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDuration),
                of: originalAudioTrack,
                at: .zero
            )
        }

        // Add music audio track — loop if shorter than video
        guard let musicTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let compositionMusicTrack = composition.addMutableTrack(
                  withMediaType: .audio,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            NavLog.warning("Audio mix: no audio track in music file, skipping mix", category: .general)
            try? FileManager.default.removeItem(at: audioLocalURL)
            return videoURL
        }

        // Insert music audio, looping if needed to fill the video duration
        var insertionTime = CMTime.zero
        let videoSeconds = CMTimeGetSeconds(videoDuration)
        let musicSeconds = CMTimeGetSeconds(audioDuration)

        // Guard against zero-duration audio which would cause an infinite loop
        guard musicSeconds > 0 else {
            NavLog.warning("Audio mix: music preview has zero duration, skipping mix", category: .general)
            try? FileManager.default.removeItem(at: audioLocalURL)
            return videoURL
        }

        // Calculate the time range within the music to use (respecting startMs offset)
        let clampedStartSeconds = min(musicStartSeconds, musicSeconds - 0.1)
        let effectiveStartTime = clampedStartSeconds > 0
            ? CMTime(seconds: clampedStartSeconds, preferredTimescale: 600)
            : CMTime.zero
        let availableMusicFromStart = CMTimeSubtract(audioDuration, effectiveStartTime)
        let useOffset = CMTimeGetSeconds(availableMusicFromStart) > 0

        if useOffset && clampedStartSeconds > 0 {
            // First insertion: from startMs offset to end of music track
            let remaining = CMTimeSubtract(videoDuration, insertionTime)
            let firstInsertDuration = CMTimeMinimum(availableMusicFromStart, remaining)
            try compositionMusicTrack.insertTimeRange(
                CMTimeRange(start: effectiveStartTime, duration: firstInsertDuration),
                of: musicTrack,
                at: insertionTime
            )
            insertionTime = CMTimeAdd(insertionTime, firstInsertDuration)
        } else if clampedStartSeconds > 0 {
            NavLog.warning("Audio mix: music start offset exceeds duration, using full track from beginning", category: .general)
        }

        // Subsequent insertions: loop full track from beginning if video is longer
        while CMTimeGetSeconds(insertionTime) < videoSeconds {
            let remaining = CMTimeSubtract(videoDuration, insertionTime)
            let insertDuration = CMTimeMinimum(audioDuration, remaining)
            try compositionMusicTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: insertDuration),
                of: musicTrack,
                at: insertionTime
            )
            insertionTime = CMTimeAdd(insertionTime, insertDuration)
        }

        NavLog.info("Audio mix: composition built (video=\(String(format: "%.1f", videoSeconds))s, music=\(String(format: "%.1f", musicSeconds))s, startOffset=\(String(format: "%.1f", musicStartSeconds))s, musicVol=\(musicVolume))", category: .general)

        // 4. Audio mix parameters — control volume levels
        let audioMix = AVMutableAudioMix()
        var mixParams: [AVMutableAudioMixInputParameters] = []

        // Original video audio volume
        if let videoAudioTrack = compositionVideoAudioTrack {
            let params = AVMutableAudioMixInputParameters(track: videoAudioTrack)
            params.setVolume(videoVolume, at: .zero)
            mixParams.append(params)
        }

        // Music audio volume
        let musicParams = AVMutableAudioMixInputParameters(track: compositionMusicTrack)
        musicParams.setVolume(musicVolume, at: .zero)
        mixParams.append(musicParams)

        audioMix.inputParameters = mixParams

        // 5. Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mixed_\(UUID().uuidString).mp4")

        // AVAssetExportPresetPassthrough ignores AVMutableAudioMix volume parameters,
        // so we must use a re-encoding preset. Preserve full video quality by matching
        // the source resolution — compress audio bitrate instead of downscaling video.
        // Video is the main experience; audio is a tiny fraction of the file size.
        let sourceShortSide: Int = await {
            let size = try? await videoTrack.load(.naturalSize)
            let transform = try? await videoTrack.load(.preferredTransform)
            guard let size, let transform else { return 1080 }
            let transformed = size.applying(transform)
            return Int(min(abs(transformed.width), abs(transformed.height)))
        }()

        let preset: String = {
            let compatible = AVAssetExportSession.exportPresets(compatibleWith: composition)
            // Match source resolution to preserve video quality
            let ladder: [(Int, String)] = [
                (2160, AVAssetExportPreset3840x2160),
                (1080, AVAssetExportPreset1920x1080),
                (720,  AVAssetExportPreset1280x720),
                (540,  AVAssetExportPreset960x540),
                (480,  AVAssetExportPreset640x480),
            ]
            for (height, presetName) in ladder {
                if height <= sourceShortSide && compatible.contains(presetName) {
                    return presetName
                }
            }
            if compatible.contains(AVAssetExportPreset1280x720) {
                return AVAssetExportPreset1280x720
            }
            return AVAssetExportPresetMediumQuality
        }()

        NavLog.info("Audio mix: using export preset \(preset)", category: .general)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: preset
        ) else {
            NavLog.error("Audio mix: failed to create export session", category: .general)
            try? FileManager.default.removeItem(at: audioLocalURL)
            return videoURL
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.fileLengthLimit = Self.maxUploadBytes  // Cap at 100MB to avoid second compress pass
        exportSession.audioMix = audioMix

        // Track progress — map export to 0.2–1.0 range (download was 0–0.2)
        let progressTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let p = 0.2 + Double(exportSession.progress) * 0.8
                await MainActor.run { self?.phase = .mixingAudio(progress: p) }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        await exportSession.export()
        progressTask.cancel()

        // Clean up temp audio file
        try? FileManager.default.removeItem(at: audioLocalURL)

        guard exportSession.status == .completed else {
            let errMsg = exportSession.error?.localizedDescription ?? "Unknown error"
            NavLog.error("Audio mix: export failed — \(errMsg)", category: .general)
            // Fall back to video without music rather than failing the upload
            return videoURL
        }

        let outSize = ((try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0)
        NavLog.info("Audio mix: complete (\(outSize / 1024)KB)", category: .general)

        return outputURL
    }

    // MARK: - Thumbnail Extraction

    private static func extractThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // 540x960 is sufficient for the preview area (~360pt) and filter thumbnails,
        // while being ~4× fewer pixels than 1080×1920 for faster generation.
        generator.maximumSize = CGSize(width: 540, height: 960)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    // MARK: - Multipart File Builder

    private func buildMultipartFile(
        at fileURL: URL,
        boundary: String,
        videoURL: URL,
        caption: String,
        scope: String,
        music: ReelMusic? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) throws {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        // Caption field
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
        handle.write("\(caption)\r\n".data(using: .utf8)!)

        // Scope field (global or local)
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"scope\"\r\n\r\n".data(using: .utf8)!)
        handle.write("\(scope)\r\n".data(using: .utf8)!)

        // Location fields (optional)
        if let location, !location.isEmpty {
            handle.write("--\(boundary)\r\n".data(using: .utf8)!)
            handle.write("Content-Disposition: form-data; name=\"location\"\r\n\r\n".data(using: .utf8)!)
            handle.write("\(location)\r\n".data(using: .utf8)!)
        }
        // Filter out null island (0,0) and obviously invalid coordinates
        let validCoords = latitude != nil && longitude != nil
            && (abs(latitude!) > 0.1 || abs(longitude!) > 0.1)
        if validCoords, let latitude {
            handle.write("--\(boundary)\r\n".data(using: .utf8)!)
            handle.write("Content-Disposition: form-data; name=\"latitude\"\r\n\r\n".data(using: .utf8)!)
            handle.write("\(latitude)\r\n".data(using: .utf8)!)
        }
        if validCoords, let longitude {
            handle.write("--\(boundary)\r\n".data(using: .utf8)!)
            handle.write("Content-Disposition: form-data; name=\"longitude\"\r\n\r\n".data(using: .utf8)!)
            handle.write("\(longitude)\r\n".data(using: .utf8)!)
        }

        // Music fields (optional)
        if let music {
            var musicFields: [(String, String)] = [
                ("music_id", music.id),
                ("music_title", music.title),
                ("music_artist", music.artist),
            ]
            if let v = music.artworkURL { musicFields.append(("music_artwork_url", v)) }
            if let v = music.previewURL { musicFields.append(("music_preview_url", v)) }
            if let v = music.durationMs { musicFields.append(("music_duration_ms", "\(v)")) }
            if let v = music.startMs { musicFields.append(("music_start_ms", "\(v)")) }

            for (name, value) in musicFields {
                handle.write("--\(boundary)\r\n".data(using: .utf8)!)
                handle.write("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
                handle.write("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // Video file field — detect format from extension
        let ext = videoURL.pathExtension.lowercased()
        let mimeType: String
        let filename: String
        switch ext {
        case "mov":
            mimeType = "video/quicktime"
            filename = "reel.mov"
        case "m4v":
            mimeType = "video/x-m4v"
            filename = "reel.m4v"
        default:
            mimeType = "video/mp4"
            filename = "reel.mp4"
        }
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        handle.write("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

        // Stream video data in chunks
        let videoHandle = try FileHandle(forReadingFrom: videoURL)
        defer { try? videoHandle.close() }

        let chunkSize = 1024 * 1024 // 1 MB
        while true {
            let chunk = videoHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            handle.write(chunk)
        }

        handle.write("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    }

    // MARK: - Upload with Progress

    /// Uploads the file and tracks progress by polling the URLSessionTask.
    /// Uses a completion-handler-based task so the continuation is guaranteed to
    /// resume exactly once — eliminates the delegate continuation leak.
    private func uploadWithProgress(
        request: URLRequest,
        fileURL: URL,
        totalSize: Int64
    ) async throws -> (Data, URLResponse) {
        NavLog.info("Reel upload: upload task starting (\(totalSize / 1024)KB)", category: .network)

        return try await withCheckedThrowingContinuation { continuation in
            let task = uploadSession.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }

            // Poll progress by reading the task's counters every 250ms.
            // Stops when the upload task completes OR this structured task is cancelled.
            let progressPoller = Task.detached { [weak self] in
                while !Task.isCancelled {
                    let sent = task.countOfBytesSent
                    let total = task.countOfBytesExpectedToSend
                    if total > 0 {
                        let fraction = Double(sent) / Double(total)
                        await MainActor.run {
                            // Only update if still in uploading phase — don't overwrite .done/.failed
                            if case .uploading = self?.phase {
                                self?.phase = .uploading(progress: fraction)
                            }
                        }
                    }
                    // Stop polling once the task has finished
                    if task.state == .completed || task.state == .canceling { break }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            // Store the poller so post() can cancel it before setting .done
            Task { @MainActor [weak self] in
                self?.activeProgressPoller = progressPoller
            }

            task.resume()
        }
    }

    /// Kept for AppDelegate compatibility — no-op now that we use foreground sessions.
    public func handleBackgroundSessionEvents(completionHandler: @escaping () -> Void) {
        // Background URL sessions removed — call the completion handler immediately
        completionHandler()
    }
}
