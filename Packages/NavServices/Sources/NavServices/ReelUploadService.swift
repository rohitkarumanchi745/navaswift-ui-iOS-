import Foundation
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

    public var progress: Double {
        // Pipeline order: mixAudio → compress → upload
        switch self {
        case .mixingAudio(let p): return p * 0.10
        case .compressing(let p): return 0.10 + p * 0.15
        case .awaitingFilter: return 0.15
        case .exportingFilter(let p): return 0.15 + p * 0.2
        case .readyToPost: return 0.35
        case .uploading(let p): return 0.35 + p * 0.6
        case .done: return 1.0
        default: return 0.0
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
    private var lastPostAuthToken: String?

    public init() {}

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
    public func post(caption: String, scope: String = "global", music: ReelMusic? = nil, musicVolume: Float = 0.5, authToken: String?) {
        // Store params for retry
        lastPostCaption = caption
        lastPostScope = scope
        lastPostMusic = music
        lastPostMusicVolume = musicVolume
        lastPostAuthToken = authToken

        guard let videoURL = filteredURL else {
            NavLog.error("Reel upload: no filtered video URL available", category: .network)
            phase = .failed(message: "No video to upload. Please try again.")
            return
        }

        Task {
            do {
                var uploadVideoURL = videoURL

                // Mix music audio into video first (uses Passthrough — fast, no re-encode)
                if let music, let previewURLString = music.previewURL,
                   let previewURL = URL(string: previewURLString) {
                    phase = .mixingAudio(progress: 0)
                    uploadVideoURL = try await mixAudioIntoVideo(
                        videoURL: uploadVideoURL,
                        musicURL: previewURL,
                        musicVolume: musicVolume,
                        videoVolume: 1.0 - musicVolume
                    )
                }

                // Smart compression: if the video exceeds 50MB, progressively
                // downscale (2160p → 1080p → 720p → 480p) until it fits.
                phase = .compressing(progress: 0)
                uploadVideoURL = try await compressForUpload(videoURL: uploadVideoURL)

                phase = .uploading(progress: 0)

                let boundary = UUID().uuidString
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent("reel_upload_\(UUID().uuidString).tmp")

                try buildMultipartFile(
                    at: tempFile,
                    boundary: boundary,
                    videoURL: uploadVideoURL,
                    caption: caption,
                    scope: scope,
                    music: music
                )

                let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempFile.path)[.size] as? Int64) ?? 0
                NavLog.info("Reel upload: multipart file built (\(fileSize) bytes)", category: .network)

                let baseURL = AppConfig.shared.apiBaseURL
                guard let url = URL(string: "\(baseURL)/reels") else {
                    phase = .failed(message: "Invalid upload URL")
                    return
                }

                NavLog.info("Reel upload: POST \(url.absoluteString)", category: .network)

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 300
                request.setValue(
                    "multipart/form-data; boundary=\(boundary)",
                    forHTTPHeaderField: "Content-Type"
                )
                if let token = authToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    NavLog.info("Reel upload: auth token attached", category: .network)
                } else {
                    NavLog.error("Reel upload: NO auth token available", category: .network)
                }

                let (data, response) = try await uploadWithProgress(
                    request: request,
                    fileURL: tempFile,
                    totalSize: fileSize
                )

                try? FileManager.default.removeItem(at: tempFile)

                guard let httpResponse = response as? HTTPURLResponse else {
                    phase = .failed(message: "Invalid server response")
                    return
                }

                let body = String(data: data, encoding: .utf8) ?? ""
                NavLog.info("Reel upload: response \(httpResponse.statusCode) - \(body)", category: .network)

                if httpResponse.statusCode >= 400 {
                    NavLog.error("Reel upload failed (\(httpResponse.statusCode)): \(body)", category: .network)
                    phase = .failed(message: "Upload failed (status \(httpResponse.statusCode))")
                    return
                }

                struct UploadResponse: Codable {
                    let reel_id: Int?
                    let message: String?
                }

                if let result = try? JSONDecoder().decode(UploadResponse.self, from: data) {
                    let reelId = result.reel_id ?? 0
                    NavLog.info("Reel upload success: reel_id=\(reelId)", category: .network)
                    phase = .done(reelId: reelId)
                } else {
                    // Server returned 2xx but unexpected body format — still treat as success
                    NavLog.info("Reel upload: 2xx response but unexpected body: \(body)", category: .network)
                    phase = .done(reelId: 0)
                }

                NotificationCenter.default.post(name: Self.didFinishUploadNotification, object: nil)

                // Auto-dismiss after 3 seconds
                try? await Task.sleep(for: .seconds(3))
                if case .done = phase {
                    reset()
                }

            } catch is CancellationError {
                NavLog.info("Reel upload cancelled", category: .network)
                reset()
            } catch let urlError as URLError {
                NavLog.error("Reel upload URLError [\(urlError.code.rawValue)]: \(urlError.localizedDescription)", category: .network)
                switch urlError.code {
                case .timedOut:
                    phase = .failed(message: "Upload timed out. Try a shorter video or better connection.")
                case .cannotConnectToHost, .notConnectedToInternet, .networkConnectionLost:
                    phase = .failed(message: "Could not connect to server. Check your connection and try again.")
                default:
                    phase = .failed(message: "Network error: \(urlError.localizedDescription)")
                }
            } catch {
                NavLog.error("Reel upload error: \(error)", category: .network)
                phase = .failed(message: error.localizedDescription)
            }
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
        lastPostAuthToken = nil
    }

    // MARK: - Smart Compression (progressive downscale if over 50MB)

    private static let maxUploadBytes: Int64 = 50 * 1024 * 1024 // 50 MB

    /// Resolution presets to try in descending order.
    /// Each entry is (label for logging, AVAssetExportSession preset name).
    private static let resolutionLadder: [(String, String)] = [
        ("2160p", AVAssetExportPreset3840x2160),
        ("1080p", AVAssetExportPreset1920x1080),
        ("720p",  AVAssetExportPreset1280x720),
        ("540p",  AVAssetExportPreset960x540),
        ("480p",  AVAssetExportPreset640x480),
    ]

    /// Checks the file size of `videoURL`. If it's under 50MB, returns it unchanged.
    /// Otherwise re-exports at progressively lower resolutions until it fits.
    private func compressForUpload(videoURL: URL) async throws -> URL {
        let attrs = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0

        if fileSize <= Self.maxUploadBytes {
            NavLog.info("Compress: \(fileSize / 1024)KB is under 50MB — no re-encode needed", category: .general)
            return videoURL
        }

        NavLog.info("Compress: \(fileSize / 1024)KB exceeds 50MB — starting progressive downscale", category: .general)

        let asset = AVURLAsset(url: videoURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)

        // Deduplicate presets while preserving order (e.g. 1440p and 1080p map to same preset)
        var seen = Set<String>()
        let uniquePresets = Self.resolutionLadder.filter { seen.insert($0.1).inserted && compatiblePresets.contains($0.1) }

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
                NavLog.info("Compress: \(label) fits under 50MB ✓", category: .general)
                return outputURL
            }

            // Still too large — clean up and try the next lower resolution
            try? FileManager.default.removeItem(at: outputURL)
        }

        // If nothing fits (very unlikely), return the lowest-quality export or the original
        NavLog.warning("Compress: all presets still over 50MB — uploading lowest quality available", category: .general)

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
    private func mixAudioIntoVideo(
        videoURL: URL,
        musicURL: URL,
        musicVolume: Float,
        videoVolume: Float
    ) async throws -> URL {
        NavLog.info("Audio mix: downloading music preview…", category: .general)

        // 1. Download the music preview to a local temp file
        let (audioTempURL, _) = try await URLSession.shared.download(from: musicURL)
        let audioLocalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("music_preview_\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: audioLocalURL)
        try FileManager.default.moveItem(at: audioTempURL, to: audioLocalURL)

        NavLog.info("Audio mix: preview downloaded, building composition…", category: .general)

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

        NavLog.info("Audio mix: composition built (video=\(String(format: "%.1f", videoSeconds))s, music=\(String(format: "%.1f", musicSeconds))s, musicVol=\(musicVolume))", category: .general)

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

        // Use Passthrough to avoid re-encoding the video — just mux the audio mix in.
        // Falls back to MediumQuality if Passthrough isn't compatible.
        let preset: String = {
            let compatible = AVAssetExportSession.exportPresets(compatibleWith: composition)
            if compatible.contains(AVAssetExportPresetPassthrough) {
                return AVAssetExportPresetPassthrough
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
        exportSession.audioMix = audioMix

        // Track progress
        let progressTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let p = Double(exportSession.progress)
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
        music: ReelMusic? = nil
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

    private func uploadWithProgress(
        request: URLRequest,
        fileURL: URL,
        totalSize: Int64
    ) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = UploadProgressDelegate { [weak self] fraction in
                Task { @MainActor in
                    self?.phase = .uploading(progress: fraction)
                }
            }

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600

            let session = URLSession(
                configuration: config,
                delegate: delegate,
                delegateQueue: nil
            )

            let task = session.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: APIError.invalidResponse)
                }
            }

            task.resume()
        }
    }
}

// MARK: - Upload Progress Delegate

private class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(fraction)
    }
}
