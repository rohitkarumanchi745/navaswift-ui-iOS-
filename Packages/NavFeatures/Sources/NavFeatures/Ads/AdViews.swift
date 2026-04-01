import SwiftUI
import NavCore
import NavServices

// MARK: - Native Ad Card (Discover / Reels)

/// A placeholder slot for a native ad. When the AdMob SDK is integrated, this
/// view will host a `GADNativeAdView`. Until then it shows a subtle branded card
/// that blends with the feed.
struct NativeAdCardView: View {
    let placementId: String
    @EnvironmentObject var adManager: AdManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Sponsored")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.darkCard.opacity(0.6))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("Ad")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.darkCard)
        )
        .onAppear {
            adManager.recordImpression(placementId: placementId)
        }
    }
}

// MARK: - Banner Ad View (Chat List / Inbox)

/// A slim banner ad slot pinned to the bottom of a list view.
struct BannerAdView: View {
    let placementId: String
    @EnvironmentObject var adManager: AdManager

    var body: some View {
        if adManager.shouldShowAd(placementId: placementId) {
            VStack(spacing: 0) {
                Divider().background(.white.opacity(0.1))

                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.darkCard.opacity(0.8))
                            .frame(height: 50)
                            .overlay {
                                HStack(spacing: 6) {
                                    Image(systemName: "megaphone.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("Ad")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                        Text("Sponsored")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(AppColors.darkBg)
            }
            .onAppear {
                adManager.recordImpression(placementId: placementId)
            }
        }
    }
}

// MARK: - Interstitial Ad Trigger

/// Tracks view counts and triggers an interstitial ad when the threshold is met.
/// When the AdMob SDK is added, this will call `GADInterstitialAd.present()`.
/// For now it records the impression on the backend.
struct InterstitialAdModifier: ViewModifier {
    let placementId: String
    let threshold: Int
    @Binding var viewCount: Int
    @EnvironmentObject var adManager: AdManager
    @State private var showingAd = false

    func body(content: Content) -> some View {
        content
            .onChange(of: viewCount) { _, newCount in
                if newCount > 0 && newCount % threshold == 0 && adManager.shouldShowAd(placementId: placementId) {
                    adManager.recordImpression(placementId: placementId)
                    // When AdMob SDK is integrated, present interstitial here:
                    // showingAd = true
                }
            }
    }
}

extension View {
    /// Attaches interstitial ad tracking to this view.
    func interstitialAd(placementId: String, threshold: Int, viewCount: Binding<Int>) -> some View {
        modifier(InterstitialAdModifier(placementId: placementId, threshold: threshold, viewCount: viewCount))
    }
}

// MARK: - Rewarded Ad Button

/// A button that offers the user a reward for watching an ad.
/// Shows the reward type and amount configured by the backend.
struct RewardedAdButton: View {
    let placementId: String
    let label: String
    let icon: String
    @EnvironmentObject var adManager: AdManager
    @State private var isLoading = false
    @State private var rewardGranted = false
    @State private var rewardMessage: String?

    var body: some View {
        if adManager.shouldShowAd(placementId: placementId) {
            Button {
                watchRewardedAd()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                    }
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.purpleAccent.opacity(0.8))
                .clipShape(Capsule())
            }
            .disabled(isLoading)
            .overlay(alignment: .top) {
                if let message = rewardMessage {
                    Text(message)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.success.opacity(0.9))
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .offset(y: -40)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: rewardMessage)
        }
    }

    private func watchRewardedAd() {
        isLoading = true
        let impressionId = UUID().uuidString
        // When AdMob SDK is integrated, present rewarded ad here
        // and call completeRewardedAd in the reward callback.
        // For now, simulate the reward flow:
        Task {
            let response = await adManager.completeRewardedAd(
                placementId: placementId,
                impressionId: impressionId,
                watchedFullDuration: true
            )
            isLoading = false
            if let response, response.granted {
                rewardGranted = true
                if let type = response.rewardType, let amount = response.rewardAmount {
                    rewardMessage = "+\(amount) \(type)"
                } else {
                    rewardMessage = "Reward earned!"
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                rewardMessage = nil
            }
        }
    }
}
