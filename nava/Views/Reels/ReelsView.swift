import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import Combine

// MARK: - Reel Model
struct Reel: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userAge: Int
    let userPhoto: String
    let videoUrl: String
    let caption: String
    var likes: Int
    var isLiked: Bool
    let isVerified: Bool
    let location: String
}

// MARK: - Video Player Manager
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    private var currentURL: String?
    
    func play(url: String) {
        guard url != currentURL, let videoURL = URL(string: url) else {
            player?.play()
            return
        }
        currentURL = url
        player = AVPlayer(url: videoURL)
        player?.isMuted = false
        player?.play()
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.pause()
        player = nil
        currentURL = nil
    }
}

// MARK: - ReelsView
struct ReelsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var currentIndex = 0
    @State private var reels: [Reel] = []
    @State private var showUploadSheet = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Could not load reels")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchReels() }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
                }
                .padding(32)
            } else if reels.isEmpty {
                emptyState
            } else {
                // Vertical paging reel feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                        ReelCard(reel: binding(for: index), isActive: index == currentIndex)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
            
            // Top bar overlay
            VStack {
                HStack {
                    Text("Reels")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        showUploadSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadReelView { await fetchReels() }
        }
        .task { await fetchReels() }
    }
    
    private func binding(for index: Int) -> Binding<Reel> {
        Binding(
            get: { reels[index] },
            set: { reels[index] = $0 }
        )
    }
    
    private func fetchReels() async {
        isLoading = reels.isEmpty
        errorMessage = nil
        do {
            struct ReelFeedItem: Codable {
                let id: Int
                let user_id: Int
                let video_url: String?
                let title: String?
                let description: String?
                let like_count: Int?
                let view_count: Int?
                let user_name: String?
                let user_age: Int?
                let user_photo: String?
                let is_verified: Bool?
                let location: String?
            }
            let items: [ReelFeedItem] = try await APIService.shared.get(path: "/reels/feed")
            reels = items.map { r in
                Reel(
                    id: "\(r.id)",
                    userId: "\(r.user_id)",
                    userName: r.user_name ?? "Unknown",
                    userAge: r.user_age ?? 0,
                    userPhoto: r.user_photo ?? "",
                    videoUrl: r.video_url ?? "",
                    caption: r.title ?? r.description ?? "",
                    likes: r.like_count ?? 0,
                    isLiked: false,
                    isVerified: r.is_verified ?? false,
                    location: r.location ?? ""
                )
            }
        } catch {
            if reels.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Reels Yet")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Be the first to share a moment!")
                .foregroundColor(.gray)
            
            Button {
                showUploadSheet = true
            } label: {
                Label("Upload Reel", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.brandGradient)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - ReelCard
struct ReelCard: View {
    @Binding var reel: Reel
    let isActive: Bool
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showHeart = false
    @State private var showMessageSheet = false
    @State private var messageText = ""
    @State private var messageSent = false
    
    var body: some View {
        ZStack {
            // Video player background
            Color.black.ignoresSafeArea()
            
            if !reel.videoUrl.isEmpty, URL(string: reel.videoUrl) != nil {
                VideoPlayer(player: playerManager.player)
                    .ignoresSafeArea()
                    .disabled(true) // Disable default controls, use custom
                    .onAppear {
                        if isActive {
                            playerManager.play(url: reel.videoUrl)
                        }
                    }
            } else {
                // Fallback gradient for reels without video
                LinearGradient(
                    colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            }
            
            // Heart animation on double tap
            if showHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Bottom overlay
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // User info & caption
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            AsyncImage(url: URL(string: reel.userPhoto)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(reel.userName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    if reel.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                    
                                    Text("\(reel.userAge)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                if !reel.location.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin")
                                            .font(.caption2)
                                        Text(reel.location)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        
                        if !reel.caption.isEmpty {
                            Text(reel.caption)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action buttons
                    VStack(spacing: 20) {
                        reelAction(icon: reel.isLiked ? "heart.fill" : "heart", count: reel.likes, color: reel.isLiked ? .red : .white) {
                            toggleLike()
                        }
                        
                        reelAction(icon: "bubble.right", count: nil, color: .white) {
                            showMessageSheet = true
                        }
                        
                        reelAction(icon: "paperplane", count: nil, color: .white) {}
                    }
                }
                .padding()
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onTapGesture(count: 2) {
            if !reel.isLiked {
                toggleLike()
            }
            withAnimation(.spring(response: 0.3)) {
                showHeart = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { showHeart = false }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                playerManager.play(url: reel.videoUrl)
                trackView()
            } else {
                playerManager.pause()
            }
        }
        .onDisappear {
            playerManager.stop()
        }
        .alert("Send Message", isPresented: $showMessageSheet) {
            TextField("Say something...", text: $messageText)
            Button("Send") { sendReelMessage() }
            Button("Cancel", role: .cancel) { messageText = "" }
        } message: {
            Text("Send a message to \(reel.userName)")
        }
    }
    
    private func toggleLike() {
        withAnimation(.spring(response: 0.3)) {
            reel.isLiked.toggle()
            reel.likes += reel.isLiked ? 1 : -1
        }
        Task {
            struct R: Codable { let success: Bool? }
            let path = reel.isLiked ? "/reels/like" : "/reels/unlike"
            let _: R? = try? await APIService.shared.post(path: path, body: ["reel_id": Int(reel.id) ?? 0])
        }
    }
    
    private func trackView() {
        Task {
            struct R: Codable { let success: Bool? }
            let _: R? = try? await APIService.shared.post(path: "/reels/view", body: ["reel_id": Int(reel.id) ?? 0])
        }
    }
    
    private func sendReelMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        Task {
            struct R: Codable { let success: Bool? }
            let _: R? = try? await APIService.shared.post(path: "/reels/message", body: ["reel_id": Int(reel.id) ?? 0, "content": text])
        }
    }
    
    private func reelAction(icon: String, count: Int?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                if let count {
                    Text(formatCount(count))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - UploadReelView
struct UploadReelView: View {
    @Environment(\.dismiss) var dismiss
    @State private var caption = ""
    @State private var selectedVideo: URL? = nil
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var videoThumbnail: UIImage? = nil
    var onUpload: (() async -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video picker area
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "F8F9FA"))
                                .frame(height: 300)
                                .overlay {
                                    if let thumbnail = videoThumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .overlay(alignment: .center) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 48))
                                                    .foregroundColor(.white)
                                                    .shadow(radius: 4)
                                            }
                                    } else {
                                        VStack(spacing: 12) {
                                            Image(systemName: "video.badge.plus")
                                                .font(.system(size: 48))
                                                .foregroundColor(AppColors.primary)
                                            
                                            Text("Tap to select video")
                                                .font(.headline)
                                                .foregroundColor(AppColors.textSecondary)
                                            
                                            Text("Max 30 seconds")
                                                .font(.caption)
                                                .foregroundColor(AppColors.textMuted)
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            guard let item else { return }
                            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                                selectedVideo = movie.url
                                generateThumbnail(from: movie.url)
                            }
                        }
                    }
                    
                    // Caption input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("Write a caption...", text: $caption, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(hex: "F8F9FA"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .lineLimit(3...6)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                    }
                    
                    // Upload button
                    Button {
                        uploadReel()
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isUploading ? "Uploading..." : "Upload Reel")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedVideo != nil ? AppColors.brandGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(selectedVideo == nil || isUploading)
                    .opacity(selectedVideo == nil ? 0.6 : 1)
                }
                .padding(24)
            }
            .navigationTitle("New Reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func generateThumbnail(from url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        
        Task {
            do {
                let (cgImage, _) = try await generator.image(at: .zero)
                videoThumbnail = UIImage(cgImage: cgImage)
            } catch {
                // No thumbnail — that's OK
            }
        }
    }
    
    private func uploadReel() {
        guard let videoURL = selectedVideo else {
            errorMessage = "Please select a video first."
            return
        }
        isUploading = true
        errorMessage = nil
        Task {
            do {
                let videoData = try Data(contentsOf: videoURL)
                struct UploadResponse: Codable { let id: Int? }
                let _: UploadResponse = try await APIService.shared.multipartUpload(
                    path: "/reels",
                    fileData: videoData,
                    fileName: "reel.mp4",
                    mimeType: "video/mp4",
                    fields: ["caption": caption]
                )
                await onUpload?()
                dismiss()
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
            isUploading = false
        }
    }
}

// MARK: - Video Transferable
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("reel_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

#Preview {
    ReelsView()
        .environmentObject(AuthManager())
}
