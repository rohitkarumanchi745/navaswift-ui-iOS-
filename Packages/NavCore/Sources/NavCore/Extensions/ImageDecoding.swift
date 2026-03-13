import SwiftUI
import Foundation
import CoreImage

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
