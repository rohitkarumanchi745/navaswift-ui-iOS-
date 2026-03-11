import SwiftUI
import NavCore
import NavNetworking
import NavServices

struct StudentCard: View {
    let student: StudentResult
    let isPremium: Bool
    var onLike: () -> Void
    var onMessage: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Photo
            AsyncImage(url: AppConfig.resolvePhotoURL(student.photos?.first)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(AppColors.darkCard)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.purpleAccent.opacity(0.4))
                    }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(student.name ?? "Unknown"), \(student.age ?? 0)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    if student.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "4ECDC4"))
                    }
                }

                if let uni = student.university, !uni.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.purpleAccent)
                        Text([uni, student.study].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        if let tier = student.universityTier, !tier.isEmpty {
                            Text("• \(tier)")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.purpleAccent.opacity(0.7))
                        }
                    }
                }

                HStack(spacing: 4) {
                    if let city = student.city, !city.isEmpty {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(city)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let dist = student.distance {
                        Text("• \(String(format: "%.1f", dist)) km")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 10) {
                likeButton
                messageButton
            }
        }
        .padding(14)
        .background(Color(hex: "2D3047").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Like Button

    @ViewBuilder
    private var likeButton: some View {
        let isLiked = student.interactionStatus == "liked" || student.interactionStatus == "matched"

        Button {
            if !isLiked { onLike() }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 16))
                .foregroundStyle(isLiked ? Color(hex: "FF5864") : .white.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(isLiked ? Color(hex: "FF5864").opacity(0.15) : .white.opacity(0.08))
                .clipShape(Circle())
        }
        .disabled(isLiked)
    }

    // MARK: - Message Button

    @ViewBuilder
    private var messageButton: some View {
        let isMatched = student.interactionStatus == "matched"
        let canMsg = isPremium || isMatched

        Button {
            onMessage()
        } label: {
            Image(systemName: canMsg ? "bubble.left.fill" : "lock.fill")
                .font(.system(size: canMsg ? 14 : 12))
                .foregroundStyle(canMsg ? Color(hex: "C9A0DC") : .white.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(canMsg ? Color(hex: "C9A0DC").opacity(0.15) : .white.opacity(0.05))
                .clipShape(Circle())
        }
    }
}
