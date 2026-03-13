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
        case .compressing, .awaitingFilter, .exportingFilter, .readyToPost, .uploading:
            return true
        default:
            return false
        }
    }

    public var progress: Double {
        switch self {
        case .compressing(let p): return p * 0.2
        case .awaitingFilter: return 0.2
        case .exportingFilter(let p): return 0.2 + p * 0.3
        case .readyToPost: return 0.5
        case .uploading(let p): return 0.5 + p * 0.45
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

    // Internal pipeline state
    private var compressedURL: URL?
    private var filteredURL: URL?
    private var compressionTask: Task<URL, Error>?
    private var filterExportTask: Task<Void, Error>?
    private var currentExportSession: AVAssetExportSession?

    public init() {}

    // MARK: - Step 1: Prepare (called immediately on video pick)

    /// Extracts thumbnail and starts H.264 compression in background.
    public func prepare(localURL: URL) {
        reset()
        phase = .compressing(progress: 0)

        // Extract thumbnail immediately
        Task {
            let thumb = await Self.extractThumbnail(from: localURL)
            self.thumbnail = thumb
        }

        // Start H.264 compression in background
        compressionTask = Task.detached { [weak self] in
            let asset = AVURLAsset(url: localURL)

            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetMediumQuality
            ) else {
                throw VideoFilterError.compressionFailed("Cannot create export session")
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("compressed_\(UUID().uuidString).mp4")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true

            // Poll compression progress
            let progressTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    let p = Double(exportSession.progress)
                    self?.phase = .compressing(progress: p)
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            await exportSession.export()
            progressTask.cancel()

            guard exportSession.status == .completed else {
                if exportSession.status == .cancelled {
                    throw VideoFilterError.cancelled
                }
                throw VideoFilterError.compressionFailed(
                    exportSession.error?.localizedDescription ?? "Unknown"
                )
            }

            await MainActor.run {
                self?.compressedURL = outputURL
                self?.phase = .awaitingFilter
            }

            NavLog.info("Compression complete: \(outputURL.lastPathComponent)", category: .general)
            return outputURL
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
    public func post(caption: String, authToken: String?) {
        guard let videoURL = filteredURL else { return }

        Task {
            phase = .uploading(progress: 0)

            do {
                let boundary = UUID().uuidString
                let tempFile = FileManager.default.temporaryDirectory
                    .appendingPathComponent("reel_upload_\(UUID().uuidString).tmp")

                try buildMultipartFile(
                    at: tempFile,
                    boundary: boundary,
                    videoURL: videoURL,
                    caption: caption
                )

                let baseURL = AppConfig.shared.apiBaseURL
                guard let url = URL(string: "\(baseURL)/reels") else {
                    phase = .failed(message: "Invalid upload URL")
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
                }

                let videoSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64) ?? 0

                let (data, response) = try await uploadWithProgress(
                    request: request,
                    fileURL: tempFile,
                    totalSize: videoSize
                )

                try? FileManager.default.removeItem(at: tempFile)

                guard let httpResponse = response as? HTTPURLResponse else {
                    phase = .failed(message: "Invalid server response")
                    return
                }

                if httpResponse.statusCode >= 400 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    NavLog.error("Reel upload failed (\(httpResponse.statusCode)): \(body)", category: .network)
                    phase = .failed(message: "Upload failed (status \(httpResponse.statusCode))")
                    return
                }

                struct UploadResponse: Codable {
                    let reel_id: Int?
                    let message: String?
                }
                let result = try JSONDecoder().decode(UploadResponse.self, from: data)
                let reelId = result.reel_id ?? 0

                phase = .done(reelId: reelId)
                NotificationCenter.default.post(name: Self.didFinishUploadNotification, object: nil)

                // Auto-dismiss after 3 seconds
                try? await Task.sleep(for: .seconds(3))
                if case .done = phase {
                    reset()
                }

            } catch is CancellationError {
                reset()
            } catch {
                NavLog.error("Reel upload error: \(error.localizedDescription)", category: .network)
                phase = .failed(message: error.localizedDescription)
            }
        }
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
    }

    // MARK: - Thumbnail Extraction

    private static func extractThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
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
        caption: String
    ) throws {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        // Caption field
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
        handle.write("\(caption)\r\n".data(using: .utf8)!)

        // Video file field
        handle.write("--\(boundary)\r\n".data(using: .utf8)!)
        handle.write("Content-Disposition: form-data; name=\"video\"; filename=\"reel.mp4\"\r\n".data(using: .utf8)!)
        handle.write("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)

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

            let session = URLSession(
                configuration: .default,
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
