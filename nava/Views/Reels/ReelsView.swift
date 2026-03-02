import SwiftUI
import AVFoundation

// MARK: - Reel Model
struct Reel: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userAge: Int
    let userPhoto: String
    let videoUrl: String
    let caption: String
    let likes: Int
    let isLiked: Bool
    let isVerified: Bool
    let location: String
    
    static let demo: [Reel] = [
        Reel(id: "1", userId: "u1", userName: "Priya", userAge: 26, userPhoto: "https://i.pravatar.cc/300?img=1",
             videoUrl: "", caption: "Weekend vibes in Hyderabad! 🌆", likes: 234, isLiked: false, isVerified: true, location: "Hyderabad"),
        Reel(id: "2", userId: "u2", userName: "Ananya", userAge: 24, userPhoto: "https://i.pravatar.cc/300?img=5",
             videoUrl: "", caption: "Coffee & conversations ☕", likes: 189, isLiked: true, isVerified: false, location: "Bangalore"),
        Reel(id: "3", userId: "u3", userName: "Meera", userAge: 28, userPhoto: "https://i.pravatar.cc/300?img=9",
             videoUrl: "", caption: "Dancing through life 💃", likes: 567, isLiked: false, isVerified: true, location: "Chennai"),
    ]
}

// MARK: - ReelsView
struct ReelsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var currentIndex = 0
    @State private var reels: [Reel] = Reel.demo
    @State private var showUploadSheet = false
    @State private var showComments = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if reels.isEmpty {
                emptyState
            } else {
                // Vertical paging reel feed
                TabView(selection: $currentIndex) {
                    ForEach(Array(reels.enumerated()), id: \.element.id) { index, reel in
                        ReelCard(reel: reel, isActive: index == currentIndex)
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
            UploadReelView()
        }
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
    let reel: Reel
    let isActive: Bool
    @State private var isLiked = false
    @State private var showHeart = false
    
    var body: some View {
        ZStack {
            // Background placeholder (would be video player)
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Video placeholder
            VStack {
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
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
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin")
                                        .font(.caption2)
                                    Text(reel.location)
                                        .font(.caption)
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Text(reel.caption)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action buttons
                    VStack(spacing: 20) {
                        reelAction(icon: isLiked ? "heart.fill" : "heart", count: reel.likes + (isLiked ? 1 : 0), color: isLiked ? .red : .white) {
                            withAnimation(.spring(response: 0.3)) {
                                isLiked.toggle()
                            }
                        }
                        
                        reelAction(icon: "bubble.right", count: 42, color: .white) {}
                        
                        reelAction(icon: "paperplane", count: nil, color: .white) {}
                        
                        reelAction(icon: "bookmark", count: nil, color: .white) {}
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
            withAnimation(.spring(response: 0.3)) {
                isLiked = true
                showHeart = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showHeart = false
                }
            }
        }
        .onAppear {
            isLiked = reel.isLiked
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video picker area
                    Button {
                        // Would open video picker
                    } label: {
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "F8F9FA"))
                                .frame(height: 300)
                                .overlay {
                                    VStack(spacing: 12) {
                                        Image(systemName: "video.badge.plus")
                                            .font(.system(size: 48))
                                            .foregroundColor(AppColors.primary)
                                        
                                        Text("Tap to select video")
                                            .font(.headline)
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Text("Max 15 seconds")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textMuted)
                                    }
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
                    
                    // Upload button
                    Button {
                        isUploading = true
                        // Would upload
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isUploading = false
                            dismiss()
                        }
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
                        .background(AppColors.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isUploading)
                    .opacity(isUploading ? 0.7 : 1)
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
}

#Preview {
    ReelsView()
        .environmentObject(AuthManager())
}
