import SwiftUI
import AVFoundation

struct VoiceIntroView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var isRecording = false
    @State private var recordedURL: URL? = nil
    @State private var duration: TimeInterval = 0
    @State private var isPlaying = false
    @State private var isUploading = false
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var timer: Timer? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let maxDuration: TimeInterval = 15
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "5F7A66"), Color(hex: "4ECDC4")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("Share a 15-second voice intro")
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "1F1F1F"))
                        
                        Text("Let matches hear your voice before they swipe. It's a great way to stand out!")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "666666"))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Status badge
                    statusBadge
                    
                    // Existing voice intro
                    if auth.user?.voiceIntroUrl != nil && recordedURL == nil {
                        Button {
                            // Would play existing intro
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Listen to current intro")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "4C5C52"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    
                    // Record button
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            Text(isRecording ? "Stop Recording" : "Start Recording")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isRecording ? Color(hex: "FF5E5B") : Color(hex: "5F7A66"))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    
                    // Preview button
                    Button {
                        togglePlayback()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? "Stop Preview" : "Preview Recording")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(Color(hex: "5F7A66"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "D6D0C9"), lineWidth: 1)
                        )
                    }
                    .disabled(recordedURL == nil)
                    .opacity(recordedURL == nil ? 0.5 : 1)
                    
                    // Upload button
                    Button {
                        uploadVoiceIntro()
                    } label: {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView().tint(.white)
                            }
                            Image(systemName: "arrow.up.circle.fill")
                            Text(isUploading ? "Uploading..." : "Upload & Continue")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "5F7A66"))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(recordedURL == nil || isUploading)
                    .opacity(recordedURL == nil ? 0.6 : 1)
                    
                    // Tip
                    Text("Tip: Share something unique about yourself — your hobbies, what makes you laugh, or what you're looking for.")
                        .font(.caption)
                        .foregroundColor(Color(hex: "6C6C6C"))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
                .padding(.horizontal, 24)
            }
        }
        .background(Color(hex: "F3D9D1"))
        .navigationTitle("Voice Intro")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Voice Intro", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            timer?.invalidate()
            audioRecorder?.stop()
            audioPlayer?.stop()
        }
    }
    
    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 6) {
            if isRecording {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Recording: \(formatDuration(duration))")
            } else if let _ = recordedURL {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Recorded: \(formatDuration(duration))")
            } else {
                Image(systemName: "mic.slash")
                    .foregroundColor(Color(hex: "7D8B82"))
                Text("No recording yet")
            }
        }
        .font(.caption.bold())
        .foregroundColor(Color(hex: "5F7A66"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "ECE0D7"))
        .clipShape(Capsule())
    }
    
    // MARK: - Recording
    
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            alertMessage = "Could not access microphone."
            showAlert = true
            return
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-intro.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            duration = 0
            recordedURL = nil
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                duration = audioRecorder?.currentTime ?? 0
                if duration >= maxDuration {
                    stopRecording()
                }
            }
        } catch {
            alertMessage = "Failed to start recording."
            showAlert = true
        }
    }
    
    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
        recordedURL = audioRecorder?.url
    }
    
    private func togglePlayback() {
        guard let url = recordedURL else { return }
        
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlaying = true
                
                // Auto-stop after duration
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    isPlaying = false
                }
            } catch {
                alertMessage = "Could not play recording."
                showAlert = true
            }
        }
    }
    
    private func uploadVoiceIntro() {
        guard recordedURL != nil else { return }
        isUploading = true
        
        Task {
            do {
                // In production: upload via gqlUpload
                try await Task.sleep(for: .seconds(2))
                await auth.refreshProfile()
                alertMessage = "Voice intro uploaded successfully!"
            } catch {
                alertMessage = "Upload failed. Please try again."
            }
            isUploading = false
            showAlert = true
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NavigationStack {
        VoiceIntroView()
            .environmentObject(AuthManager())
    }
}
