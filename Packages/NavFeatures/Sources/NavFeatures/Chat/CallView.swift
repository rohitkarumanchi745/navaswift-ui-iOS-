import SwiftUI
import AVFoundation
import NavCore
import NavNetworking
import NavServices

// MARK: - Camera Preview (UIKit bridge)

#if canImport(UIKit)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
#endif

// MARK: - Call View

struct CallView: View {
    @EnvironmentObject var callManager: CallManager
    @Environment(\.dismiss) private var dismiss

    @State private var captureSession: AVCaptureSession?
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            // Background
            backgroundView

            // Content based on call state
            VStack(spacing: 0) {
                switch callManager.callState {
                case .outgoing:
                    outgoingCallView
                case .incoming:
                    incomingCallView
                case .connecting:
                    connectingView
                case .active:
                    activeCallView
                case .ended(let reason):
                    endedView(reason: reason)
                case .idle:
                    EmptyView()
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear {
            if callManager.callType == .video {
                setupCamera()
            }
        }
        .onDisappear {
            stopCamera()
        }
        .onChange(of: callManager.callState) { _, newState in
            if case .idle = newState {
                dismiss()
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if callManager.callType == .video && callManager.callState == .active {
            // Video call: show camera preview as background
            #if canImport(UIKit)
            if let session = captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            #else
            Color.black.ignoresSafeArea()
            #endif

            // Simulated remote video (partner photo as placeholder)
            Color.black.opacity(0.3).ignoresSafeArea()
        } else {
            // Audio call or pre-connect: gradient background
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Outgoing Call

    private var outgoingCallView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Pulsing avatar
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animatePulse ? 1.3 : 1.0)
                    .opacity(animatePulse ? 0 : 0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: animatePulse)

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animatePulse ? 1.2 : 1.0)
                    .opacity(animatePulse ? 0 : 0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.3), value: animatePulse)

                partnerAvatar(size: 120)
            }
            .onAppear { animatePulse = true }

            VStack(spacing: 8) {
                Text(callManager.partnerName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(callManager.callType == .video ? "Video calling..." : "Calling...")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // End call button
            Button { callManager.endCall(reason: "Call cancelled") } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(hex: "E74C3C"))
                    .clipShape(Circle())
            }

            Spacer().frame(height: 60)
        }
    }

    // MARK: - Incoming Call

    private var incomingCallView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Avatar
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animatePulse ? 1.3 : 1.0)
                    .opacity(animatePulse ? 0 : 0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: animatePulse)

                partnerAvatar(size: 120)
            }
            .onAppear { animatePulse = true }

            VStack(spacing: 8) {
                Text(callManager.partnerName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(callManager.callType == .video ? "Incoming video call" : "Incoming call")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Accept / Decline
            HStack(spacing: 60) {
                // Decline
                VStack(spacing: 8) {
                    Button { callManager.declineCall() } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Color(hex: "E74C3C"))
                            .clipShape(Circle())
                    }
                    Text("Decline")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Accept
                VStack(spacing: 8) {
                    Button {
                        // Token would come from auth - using empty for now
                        callManager.acceptCall(token: "")
                    } label: {
                        Image(systemName: callManager.callType == .video ? "video.fill" : "phone.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Color(hex: "4CAF50"))
                            .clipShape(Circle())
                    }
                    Text("Accept")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer().frame(height: 60)
        }
    }

    // MARK: - Connecting

    private var connectingView: some View {
        VStack(spacing: 24) {
            Spacer()

            partnerAvatar(size: 120)

            VStack(spacing: 8) {
                Text(callManager.partnerName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Connecting...")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)

            Spacer()

            Button { callManager.endCall(reason: "Call cancelled") } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(hex: "E74C3C"))
                    .clipShape(Circle())
            }

            Spacer().frame(height: 60)
        }
    }

    // MARK: - Active Call

    private var activeCallView: some View {
        VStack(spacing: 0) {
            if callManager.callType == .video {
                videoCallContent
            } else {
                audioCallContent
            }
        }
    }

    private var videoCallContent: some View {
        ZStack {
            // Local camera preview (small PiP in corner)
            VStack {
                HStack {
                    Spacer()
                    #if canImport(UIKit)
                    if let session = captureSession, callManager.isLocalVideoEnabled {
                        CameraPreviewView(session: session)
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8)
                            .padding(.top, 60)
                            .padding(.trailing, 16)
                    }
                    #endif
                }
                Spacer()
            }

            // Partner info overlay (top center)
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(callManager.partnerName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(callManager.formattedDuration)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.leading, 16)

                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()
                videoCallControls
                    .padding(.bottom, 50)
            }
        }
    }

    private var audioCallContent: some View {
        VStack(spacing: 24) {
            Spacer()

            partnerAvatar(size: 120)

            VStack(spacing: 8) {
                Text(callManager.partnerName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(callManager.formattedDuration)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            audioCallControls
                .padding(.bottom, 50)
        }
    }

    // MARK: - Controls

    private var videoCallControls: some View {
        HStack(spacing: 24) {
            // Mute
            callControlButton(
                icon: callManager.isMuted ? "mic.slash.fill" : "mic.fill",
                isActive: callManager.isMuted,
                action: { callManager.toggleMute() }
            )

            // Camera flip
            callControlButton(
                icon: "camera.rotate.fill",
                isActive: false,
                action: { callManager.toggleCamera() }
            )

            // Toggle video
            callControlButton(
                icon: callManager.isLocalVideoEnabled ? "video.fill" : "video.slash.fill",
                isActive: !callManager.isLocalVideoEnabled,
                action: { callManager.toggleVideo() }
            )

            // End call
            Button { callManager.endCall() } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color(hex: "E74C3C"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var audioCallControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 36) {
                // Mute
                VStack(spacing: 6) {
                    callControlButton(
                        icon: callManager.isMuted ? "mic.slash.fill" : "mic.fill",
                        isActive: callManager.isMuted,
                        action: { callManager.toggleMute() }
                    )
                    Text(callManager.isMuted ? "Unmute" : "Mute")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Speaker
                VStack(spacing: 6) {
                    callControlButton(
                        icon: callManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                        isActive: callManager.isSpeakerOn,
                        action: { callManager.toggleSpeaker() }
                    )
                    Text("Speaker")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Switch to video
                VStack(spacing: 6) {
                    callControlButton(
                        icon: "video.fill",
                        isActive: false,
                        action: {
                            callManager.callType = .video
                            setupCamera()
                        }
                    )
                    Text("Video")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // End call
            Button { callManager.endCall() } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(hex: "E74C3C"))
                    .clipShape(Circle())
            }
        }
    }

    private func callControlButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isActive ? .black : .white)
                .frame(width: 52, height: 52)
                .background(isActive ? .white : .white.opacity(0.15))
                .clipShape(Circle())
        }
    }

    // MARK: - Ended

    private func endedView(reason: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            partnerAvatar(size: 100)

            VStack(spacing: 8) {
                Text(callManager.partnerName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(reason)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))

                if callManager.callDuration > 0 {
                    Text(callManager.formattedDuration)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func partnerAvatar(size: CGFloat) -> some View {
        AsyncImage(url: AppConfig.resolvePhotoURL(callManager.partnerPhoto)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle()
                .fill(.white.opacity(0.1))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white.opacity(0.3))
                }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2)
        )
    }

    // MARK: - Camera

    private func setupCamera() {
        #if os(iOS)
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }

            let session = AVCaptureSession()
            session.sessionPreset = .medium

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: callManager.isCameraFront ? .front : .back
            ) else { return }

            guard let input = try? AVCaptureDeviceInput(device: device) else { return }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            DispatchQueue.main.async {
                captureSession = session
            }

            Task.detached {
                session.startRunning()
            }
        }
        #endif
    }

    private func stopCamera() {
        Task.detached { [captureSession] in
            captureSession?.stopRunning()
        }
        captureSession = nil
    }
}
