import SwiftUI

/// Wraps an AsyncImage with a blur overlay and moderation info when content is flagged.
/// Drop-in replacement for photo display sites that need moderation transparency.
///
/// Usage:
/// ```
/// ModeratedPhotoView(
///     url: AppConfig.resolvePhotoURL(photo),
///     status: .flagged,
///     onRequestReview: { photoId in ... }
/// )
/// ```
public struct ModeratedPhotoView: View {
    let url: URL?
    let status: ModerationStatus
    let photoId: String
    let onRequestReview: ((String) -> Void)?

    @State private var showExplanation = false
    /// Tracks whether the user has submitted an appeal from this view instance.
    @State private var appealSent = false

    public init(
        url: URL?,
        status: ModerationStatus,
        photoId: String = "",
        onRequestReview: ((String) -> Void)? = nil
    ) {
        self.url = url
        self.status = status
        self.photoId = photoId
        self.onRequestReview = onRequestReview
    }

    public var body: some View {
        ZStack {
            // Base photo
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
                    .overlay { ProgressView() }
            }

            // Blur + moderation overlay
            if status.isBlurred {
                // Blurred duplicate layer
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                        .blur(radius: 30)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray4))
                }

                // Dark scrim
                Color.black.opacity(0.4)

                // Moderation badge
                VStack(spacing: 12) {
                    Image(systemName: status == .rejected ? "xmark.shield.fill" : "eye.slash.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(status == .rejected ? "Photo Removed" : "Photo Under Review")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Button {
                        showExplanation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                            Text("Why was this blurred?")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // Inline status chip after appeal
                    if appealSent {
                        statusChip
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appealSent)
        .alert("Content Moderation", isPresented: $showExplanation) {
            if status.canAppeal, !appealSent, onRequestReview != nil {
                Button("Request Review") {
                    appealSent = true
                    onRequestReview?(photoId)
                }
                Button("OK", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(appealSent ? "Your appeal has been submitted and is under review." : status.reason)
        }
    }

    /// Inline chip showing current appeal status on the blurred photo.
    private var statusChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
            Text(status == .pending ? "Under review" : "Appeal sent")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.8))
        .clipShape(Capsule())
        .accessibilityIdentifier("appealStatusChip")
    }
}

#Preview("Flagged Photo") {
    VStack(spacing: 16) {
        ModeratedPhotoView(
            url: nil,
            status: .flagged,
            photoId: "demo-1",
            onRequestReview: { _ in }
        )
        .frame(width: 300, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))

        ModeratedPhotoView(
            url: nil,
            status: .rejected,
            photoId: "demo-2",
            onRequestReview: { _ in }
        )
        .frame(width: 300, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
