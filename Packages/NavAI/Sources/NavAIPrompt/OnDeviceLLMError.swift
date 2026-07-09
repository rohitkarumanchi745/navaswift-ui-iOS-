import Foundation

/// Errors surfaced by the on-device suggestion stack.
public enum OnDeviceLLMError: LocalizedError {
    /// The GGUF model isn't downloaded yet.
    case modelNotAvailable
    /// The native engine failed to load the model file.
    case modelLoadFailed(String)
    /// Inference failed.
    case inferenceFailed(String)
    /// The download failed or the file was corrupt (checksum mismatch).
    case downloadFailed(String)
    /// The device is considered too constrained to run the model.
    case deviceUnsupported

    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "The suggestion model isn't ready yet."
        case .modelLoadFailed(let m):
            return "Couldn't load the suggestion model: \(m)"
        case .inferenceFailed(let m):
            return "Couldn't generate suggestions: \(m)"
        case .downloadFailed(let m):
            return "Couldn't download the suggestion model: \(m)"
        case .deviceUnsupported:
            return "This device can't run on-device suggestions."
        }
    }
}
