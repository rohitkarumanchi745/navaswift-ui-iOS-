import SwiftUI
import Foundation
import CoreImage
import Vision

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Creates a SwiftUI Image from a PlatformImage (cross-platform).
public func platformImageView(_ image: PlatformImage) -> Image {
    #if canImport(UIKit)
    Image(uiImage: image)
    #elseif canImport(AppKit)
    Image(nsImage: image)
    #endif
}

/// Decodes image data from any format supported by the platform, including
/// iPhone ProRAW (.DNG), HEIC, HEIF, TIFF, and standard JPEG/PNG.
/// Falls back to CIImage + CIContext rendering when the platform image
/// initialiser cannot handle the raw bytes directly (e.g. DNG/RAW files).
public func decodeImageData(_ data: Data) -> PlatformImage? {
    // 1. Fast path: standard UIImage/NSImage init handles JPEG, PNG, HEIC, TIFF, GIF, BMP, etc.
    if let image = PlatformImage(data: data) {
        return image
    }

    // 2. Fallback: use CIImage for RAW/DNG and other formats that UIImage can't decode directly
    guard let ciImage = CIImage(data: data) else { return nil }
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

    #if canImport(UIKit)
    return UIImage(cgImage: cgImage)
    #elseif canImport(AppKit)
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    #endif
}

/// Detects whether the image contains at least one human face using the Vision framework.
/// Returns `true` if a face is found, `false` otherwise.
public func imageContainsFace(_ image: PlatformImage) -> Bool {
    #if canImport(UIKit)
    guard let cgImage = image.cgImage else { return false }
    #elseif canImport(AppKit)
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
    #endif

    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
        guard let results = request.results else { return false }
        return !results.isEmpty
    } catch {
        return false
    }
}

// MARK: - Face Similarity

/// Default distance threshold for face similarity comparison.
/// Lower values are stricter. Tuned for cropped-face VNFeaturePrint comparison.
public let faceSimilarityThreshold: Float = 15.0

/// Detects the largest face in the image and returns a cropped image of just the face region
/// with 30% padding around the bounding box. Returns nil if no face is detected.
public func cropFaceFromImage(_ image: PlatformImage) -> PlatformImage? {
    #if canImport(UIKit)
    guard let cgImage = image.cgImage else { return nil }
    #elseif canImport(AppKit)
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    #endif

    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch { return nil }

    guard let faces = request.results, !faces.isEmpty else { return nil }

    // Pick the largest face by area
    let largestFace = faces.max(by: {
        $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
    })!
    let box = largestFace.boundingBox

    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)

    // Convert normalized coordinates to pixel coordinates
    // Vision uses bottom-left origin; CGImage uses top-left origin
    let padding: CGFloat = 0.3
    let faceX = box.origin.x * imageWidth
    let faceY = (1 - box.origin.y - box.height) * imageHeight
    let faceW = box.width * imageWidth
    let faceH = box.height * imageHeight

    let padW = faceW * padding
    let padH = faceH * padding
    let cropRect = CGRect(
        x: max(0, faceX - padW),
        y: max(0, faceY - padH),
        width: min(imageWidth - max(0, faceX - padW), faceW + 2 * padW),
        height: min(imageHeight - max(0, faceY - padH), faceH + 2 * padH)
    )

    guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

    #if canImport(UIKit)
    return UIImage(cgImage: croppedCG)
    #elseif canImport(AppKit)
    return NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))
    #endif
}

/// Generates a VNFeaturePrintObservation for the given image.
public func generateFeaturePrint(_ image: PlatformImage) -> VNFeaturePrintObservation? {
    #if canImport(UIKit)
    guard let cgImage = image.cgImage else { return nil }
    #elseif canImport(AppKit)
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    #endif

    let request = VNGenerateImageFeaturePrintRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
        return request.results?.first
    } catch {
        return nil
    }
}

/// Computes the face similarity distance between two images.
/// Lower distance = more similar. Returns nil if feature prints cannot be generated.
public func faceSimilarityDistance(_ imageA: PlatformImage, _ imageB: PlatformImage) -> Float? {
    guard let fpA = generateFeaturePrint(imageA),
          let fpB = generateFeaturePrint(imageB) else { return nil }
    var distance: Float = 0
    do {
        try fpA.computeDistance(&distance, to: fpB)
        return distance
    } catch {
        return nil
    }
}

/// Compares a selfie against an array of reference images.
/// Returns true if the selfie face matches at least one reference within the threshold.
/// Handles face cropping internally — pass full (uncropped) images.
public func selfieFaceMatchesAnyReference(
    selfie: PlatformImage,
    references: [PlatformImage],
    threshold: Float = faceSimilarityThreshold
) -> (matches: Bool, bestDistance: Float?) {
    guard let selfieFace = cropFaceFromImage(selfie),
          let selfieFP = generateFeaturePrint(selfieFace) else {
        return (false, nil)
    }

    var bestDistance: Float?
    for reference in references {
        guard let refFace = cropFaceFromImage(reference),
              let refFP = generateFeaturePrint(refFace) else {
            continue
        }
        var distance: Float = 0
        do {
            try selfieFP.computeDistance(&distance, to: refFP)
            if bestDistance == nil || distance < bestDistance! {
                bestDistance = distance
            }
        } catch {
            continue
        }
    }

    guard let best = bestDistance else {
        return (false, nil)
    }
    return (best <= threshold, best)
}

/// Converts a PlatformImage to JPEG data with the given compression quality.
/// Handles both UIKit and AppKit platforms.
public func imageToJPEGData(_ image: PlatformImage, compressionQuality: CGFloat = 0.85) -> Data? {
    #if canImport(UIKit)
    return image.jpegData(compressionQuality: compressionQuality)
    #elseif canImport(AppKit)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    #endif
}
