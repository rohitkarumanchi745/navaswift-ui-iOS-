import Foundation
import CoreImage
import UIKit
import AVFoundation

// MARK: - VideoFilter

public enum VideoFilter: String, CaseIterable, Identifiable, Equatable {
    case original
    case vivid
    case warm
    case cool
    case vintage
    case drama
    case fade

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .vivid:    return "Vivid"
        case .warm:     return "Warm"
        case .cool:     return "Cool"
        case .vintage:  return "Vintage"
        case .drama:    return "Drama"
        case .fade:     return "Fade"
        }
    }

    public var icon: String {
        switch self {
        case .original: return "circle.slash"
        case .vivid:    return "paintpalette.fill"
        case .warm:     return "sun.max"
        case .cool:     return "snowflake"
        case .vintage:  return "camera.filters"
        case .drama:    return "theatermasks.fill"
        case .fade:     return "circle.dotted"
        }
    }

    // MARK: - Preview (UIImage → UIImage)

    /// Applies filter to a UIImage for thumbnail preview. Thread-safe.
    public func applyToImage(_ image: UIImage) -> UIImage {
        guard self != .original else { return image }
        guard let ciImage = CIImage(image: image) else { return image }
        let filtered = applyCI(to: ciImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(filtered, from: filtered.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - CIFilter Pipeline (CIImage → CIImage)

    /// Core filter pipeline used by both preview and AVVideoComposition.
    public func applyCI(to input: CIImage) -> CIImage {
        switch self {
        case .original:
            return input

        case .vivid:
            return input
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.4,
                    kCIInputContrastKey: 1.1,
                    kCIInputBrightnessKey: 0.03
                ])
                .applyingFilter("CIVibrance", parameters: [
                    "inputAmount": 0.5
                ])
                .cropped(to: input.extent)

        case .warm:
            return input
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6800, y: 0),
                    "inputTargetNeutral": CIVector(x: 5200, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.1,
                    kCIInputContrastKey: 1.05
                ])
                .cropped(to: input.extent)

        case .cool:
            return input
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 8500, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.9,
                    kCIInputContrastKey: 1.05
                ])
                .cropped(to: input.extent)

        case .vintage:
            return input
                .applyingFilter("CISepiaTone", parameters: [
                    kCIInputIntensityKey: 0.3
                ])
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.8,
                    kCIInputContrastKey: 1.1,
                    kCIInputBrightnessKey: 0.02
                ])
                .applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: 0.5,
                    kCIInputRadiusKey: 1.5
                ])
                .cropped(to: input.extent)

        case .drama:
            return input
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.85,
                    kCIInputContrastKey: 1.3,
                    kCIInputBrightnessKey: -0.02
                ])
                .applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: 0.8,
                    kCIInputRadiusKey: 2.0
                ])
                .cropped(to: input.extent)

        case .fade:
            return input
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.7,
                    kCIInputContrastKey: 0.85,
                    kCIInputBrightnessKey: 0.05
                ])
                .applyingFilter("CIColorClamp", parameters: [
                    "inputMinComponents": CIVector(x: 0.08, y: 0.08, z: 0.08, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ])
                .cropped(to: input.extent)
        }
    }

    // MARK: - Video Export (AVAssetExportSession + AVVideoComposition)

    /// Exports filtered video using AVVideoComposition with CIFilter per-frame handler.
    /// Polls `onProgress` at ~200ms intervals. Returns URL of the exported file.
    public func exportVideo(
        from sourceURL: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard self != .original else { return sourceURL }

        let asset = AVURLAsset(url: sourceURL)

        let filterRef = self
        let composition = AVVideoComposition(asset: asset) { request in
            let filtered = filterRef.applyCI(to: request.sourceImage)
            request.finish(with: filtered, context: nil)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filtered_\(rawValue)_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoFilterError.exportSessionCreationFailed
        }

        exportSession.videoComposition = composition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Poll progress on a background timer
        let progressTask = Task.detached {
            while !Task.isCancelled {
                let p = Double(exportSession.progress)
                await MainActor.run { onProgress(p) }
                try await Task.sleep(for: .milliseconds(200))
            }
        }

        await exportSession.export()
        progressTask.cancel()

        guard exportSession.status == .completed else {
            if exportSession.status == .cancelled {
                throw VideoFilterError.cancelled
            }
            throw VideoFilterError.exportFailed(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }

        return outputURL
    }
}

// MARK: - Errors

public enum VideoFilterError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(String)
    case compressionFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed: return "Could not create export session"
        case .exportFailed(let msg): return "Export failed: \(msg)"
        case .compressionFailed(let msg): return "Compression failed: \(msg)"
        case .cancelled: return "Operation cancelled"
        }
    }
}
