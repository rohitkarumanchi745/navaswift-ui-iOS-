import Foundation
import AVFoundation
import NavCore
import NavNetworking

/// Manages call state, WebSocket signaling, and local camera/microphone sessions.
/// Signaling protocol (via `/ws/call`):
///   - `{ "type": "call_offer",  "call_type": "video"|"audio", "match_id": "..." }`
///   - `{ "type": "call_answer", "accepted": true|false }`
///   - `{ "type": "call_end" }`
///   - `{ "type": "call_ice_candidate", "candidate": "..." }` (future WebRTC)
@MainActor
public class CallManager: ObservableObject {
    // MARK: - Public State
    @Published public var callState: CallState = .idle
    @Published public var callType: CallType = .audio
    @Published public var callDuration: TimeInterval = 0
    @Published public var isMuted = false
    @Published public var isSpeakerOn = false
    @Published public var isCameraFront = true
    @Published public var isLocalVideoEnabled = true
    @Published public var partnerName: String = ""
    @Published public var partnerPhoto: String = ""
    @Published public var matchId: String = ""

    public enum CallState: Equatable {
        case idle
        case outgoing       // Ringing the other person
        case incoming       // Someone is calling us
        case connecting     // Call accepted, setting up
        case active         // Call in progress
        case ended(reason: String)
    }

    public enum CallType: String {
        case audio, video
    }

    // MARK: - Private
    private var webSocketTask: URLSessionWebSocketTask?
    private var token: String = ""
    private var durationTimer: Timer?
    private var ringtonePlayer: AVAudioPlayer?

    public init() {}

    // MARK: - Start Outgoing Call

    public func startCall(type: CallType, matchId: String, partnerName: String, partnerPhoto: String, token: String) {
        self.callType = type
        self.matchId = matchId
        self.partnerName = partnerName
        self.partnerPhoto = partnerPhoto
        self.token = token
        self.callState = .outgoing
        self.callDuration = 0
        self.isMuted = false
        self.isSpeakerOn = type == .video
        self.isCameraFront = true
        self.isLocalVideoEnabled = true

        configureAudioSession(speaker: type == .video)
        connectSignaling()
        sendSignal(["type": "call_offer", "call_type": type.rawValue, "match_id": matchId])

        #if DEBUG
        // Auto-answer for demo (simulates partner picking up after 2s)
        Task {
            try? await Task.sleep(for: .seconds(2))
            if callState == .outgoing {
                callState = .connecting
                try? await Task.sleep(for: .seconds(1))
                if callState == .connecting {
                    callState = .active
                    startDurationTimer()
                }
            }
        }
        #endif
    }

    // MARK: - Handle Incoming Call

    public func handleIncomingCall(type: CallType, matchId: String, partnerName: String, partnerPhoto: String) {
        self.callType = type
        self.matchId = matchId
        self.partnerName = partnerName
        self.partnerPhoto = partnerPhoto
        self.callState = .incoming
        self.callDuration = 0
        self.isMuted = false
        self.isSpeakerOn = type == .video
        self.isCameraFront = true
        self.isLocalVideoEnabled = true
    }

    public func acceptCall(token: String) {
        self.token = token
        callState = .connecting
        configureAudioSession(speaker: callType == .video)
        connectSignaling()
        sendSignal(["type": "call_answer", "accepted": true])

        Task {
            try? await Task.sleep(for: .seconds(1))
            if callState == .connecting {
                callState = .active
                startDurationTimer()
            }
        }
    }

    public func declineCall() {
        sendSignal(["type": "call_answer", "accepted": false])
        endCall(reason: "Declined")
    }

    // MARK: - End Call

    public func endCall(reason: String = "Call ended") {
        sendSignal(["type": "call_end"])
        durationTimer?.invalidate()
        durationTimer = nil
        disconnectSignaling()
        deactivateAudioSession()
        callState = .ended(reason: reason)

        // Reset to idle after showing ended state briefly
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            callState = .idle
        }
    }

    // MARK: - Call Controls

    public func toggleMute() {
        isMuted.toggle()
    }

    public func toggleSpeaker() {
        isSpeakerOn.toggle()
        configureAudioSession(speaker: isSpeakerOn)
    }

    public func toggleCamera() {
        isCameraFront.toggle()
    }

    public func toggleVideo() {
        isLocalVideoEnabled.toggle()
        if !isLocalVideoEnabled && callType == .video {
            // Switching to audio-only mid-call
        }
    }

    public var formattedDuration: String {
        let mins = Int(callDuration) / 60
        let secs = Int(callDuration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Audio Session

    private func configureAudioSession(speaker: Bool) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: speaker ? [.defaultToSpeaker, .allowBluetooth] : [.allowBluetooth])
            try session.setActive(true)
        } catch {
            NavLog.warning("Audio session config error: \(error)", category: .general)
        }
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Timer

    private func startDurationTimer() {
        callDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.callDuration += 1
            }
        }
    }

    // MARK: - WebSocket Signaling

    private func connectSignaling() {
        let base = AppConfig.shared.wsBaseURL
        guard let url = URL(string: "\(base)/ws/call?match_id=\(matchId)&token=\(token)") else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveSignalLoop()
    }

    private func disconnectSignaling() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func sendSignal(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { _ in }
    }

    private func receiveSignalLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handleSignal(text)
                    }
                    self.receiveSignalLoop()
                case .failure:
                    break
                }
            }
        }
    }

    private func handleSignal(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "call_answer":
            if let accepted = json["accepted"] as? Bool {
                if accepted {
                    callState = .connecting
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        callState = .active
                        startDurationTimer()
                    }
                } else {
                    endCall(reason: "Call declined")
                }
            }
        case "call_end":
            durationTimer?.invalidate()
            durationTimer = nil
            callState = .ended(reason: "Call ended")
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                callState = .idle
            }
        case "call_offer":
            let callTypeStr = json["call_type"] as? String ?? "audio"
            let incomingType: CallType = callTypeStr == "video" ? .video : .audio
            handleIncomingCall(type: incomingType, matchId: matchId, partnerName: partnerName, partnerPhoto: partnerPhoto)
        default:
            break
        }
    }
}
