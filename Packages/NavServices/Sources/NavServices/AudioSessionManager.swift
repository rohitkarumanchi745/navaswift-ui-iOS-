import AVFoundation
import NavCore

/// Configures AVAudioSession for the app so audio always routes to
/// connected Bluetooth devices (AirPods, headphones, speakers).
/// Call `configure()` once at app startup and `activate()` before any playback/recording.
public final class AudioSessionManager {
    public static let shared = AudioSessionManager()
    private init() {}

    public func configure() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playAndRecord lets us both record (calls, reels) and play (music, reels)
            // .allowBluetooth       → HFP profile (hands-free, mono) for calls
            // .allowBluetoothA2DP   → A2DP profile (stereo) for media playback
            // .defaultToSpeaker     → falls back to speaker when no BT device connected
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true)
            NavLog.info("AVAudioSession configured with Bluetooth support", category: .general)
        } catch {
            NavLog.warning("AVAudioSession configuration failed: \(error.localizedDescription)", category: .general)
        }

        // Re-route to BT whenever the audio route changes (e.g. user connects AirPods)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason) else { return }

        switch changeReason {
        case .newDeviceAvailable:
            NavLog.info("Audio route: new device connected (BT or wired)", category: .general)
            // No action needed — iOS routes automatically when BT device connects
        case .oldDeviceUnavailable:
            NavLog.info("Audio route: device disconnected, re-activating session", category: .general)
            // Re-activate so we fall back cleanly to speaker
            try? AVAudioSession.sharedInstance().setActive(true)
        default:
            break
        }
    }
}
