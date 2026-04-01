import Foundation
import SwiftUI
import NavCore
import NavNetworking

// MARK: - Ad Manager

/// Centralized ad management service. Fetches placement configs from the backend,
/// enforces frequency caps / cooldowns, tracks impressions, and handles rewarded
/// ad completions. Views query `shouldShowAd(placementId:)` before rendering an ad slot
/// and call `recordImpression(placementId:)` after display.
///
/// The manager is "ad-SDK-ready": once the Google Mobile Ads SDK is added, views
/// can read the `admobUnitId` from placements and load real ad creatives. Until then,
/// ad slots remain hidden because `placements` will be empty until the backend
/// sets `ADS_ENABLED=true` and returns placements.
@MainActor
public class AdManager: ObservableObject {

    // MARK: - Published State

    /// Backend-configured placements keyed by `placementId`.
    @Published public private(set) var placements: [String: AdPlacement] = [:]

    /// User's earned consumable balances (boosts, super likes, etc.).
    @Published public private(set) var balances: ConsumableBalances = ConsumableBalances()

    /// True while the initial placement fetch is in progress.
    @Published public private(set) var isLoading = false

    // MARK: - Internal Types

    /// Generic empty response for fire-and-forget POST calls.
    private struct EmptyResponse: Decodable {}

    // MARK: - Internal State

    /// Impression timestamps per placement for frequency cap enforcement.
    private var impressionLog: [String: [Date]] = [:]

    /// Last impression date per placement for cooldown enforcement.
    private var lastImpressionDate: [String: Date] = [:]

    /// Whether the user is a premium subscriber (skip all ads).
    private var isPremium = false

    // MARK: - Init

    public init() {}

    // MARK: - Configuration

    /// Call once from navaApp after StoreKitManager is available.
    public func configure(isPremium: Bool) {
        self.isPremium = isPremium
    }

    /// Updates premium status (call when subscription state changes).
    public func updatePremiumStatus(_ premium: Bool) {
        self.isPremium = premium
    }

    // MARK: - Fetch Placements

    /// Fetches ad placements from the backend. Called on app launch.
    public func fetchPlacements() async {
        isLoading = true
        do {
            let response: AdPlacementsResponse = try await APIService.shared.get(path: "/ads/placements")

            // Backend can override premium status (premium users get empty placements)
            if let backendPremium = response.isPremium {
                isPremium = backendPremium
            }

            // If backend says don't show ads, clear placements
            if response.showAds == false {
                placements = [:]
                NavLog.debug("AdManager: ads disabled by backend", category: .general)
            } else {
                var map: [String: AdPlacement] = [:]
                for placement in response.placements where placement.enabled {
                    map[placement.placementId] = placement
                }
                placements = map
                NavLog.debug("AdManager: loaded \(map.count) placements", category: .general)
            }
        } catch {
            NavLog.debug("AdManager: failed to fetch placements — \(error.localizedDescription)", category: .general)
        }
        isLoading = false
    }

    // MARK: - Should Show Ad

    /// Returns `true` if an ad should be shown for the given placement.
    /// Checks: premium bypass, placement exists & enabled, frequency cap, cooldown.
    public func shouldShowAd(placementId: String) -> Bool {
        // Premium users never see ads
        guard !isPremium else { return false }

        // Placement must exist and be enabled
        guard let placement = placements[placementId], placement.enabled else { return false }

        // Check frequency cap (impressions in the last hour)
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let recentImpressions = (impressionLog[placementId] ?? []).filter { $0 > oneHourAgo }
        if recentImpressions.count >= placement.frequencyCapPerHour {
            return false
        }

        // Check cooldown (minutes since last impression)
        if let lastShown = lastImpressionDate[placementId] {
            let cooldownSeconds = TimeInterval(placement.cooldownMinutes * 60)
            if now.timeIntervalSince(lastShown) < cooldownSeconds {
                return false
            }
        }

        return true
    }

    /// Returns the AdMob unit ID for a placement, or `nil` if the placement
    /// doesn't exist or shouldn't show an ad right now.
    public func adUnitId(for placementId: String) -> String? {
        guard shouldShowAd(placementId: placementId) else { return nil }
        return placements[placementId]?.admobUnitId
    }

    // MARK: - Record Impression

    /// Records an ad impression locally (for frequency cap) and reports to the backend.
    public func recordImpression(placementId: String, impressionId: String = UUID().uuidString, durationMs: Int? = nil) {
        let now = Date()

        // Update local tracking
        var log = impressionLog[placementId] ?? []
        log.append(now)
        // Keep only last hour of impressions to avoid unbounded growth
        let oneHourAgo = now.addingTimeInterval(-3600)
        log = log.filter { $0 > oneHourAgo }
        impressionLog[placementId] = log
        lastImpressionDate[placementId] = now

        // Report to backend (fire-and-forget)
        let payload = AdImpressionPayload(
            placementId: placementId,
            impressionId: impressionId,
            durationMs: durationMs
        )
        Task {
            do {
                let body: [String: Any] = [
                    "placement_id": payload.placementId,
                    "impression_id": payload.impressionId,
                    "duration_ms": payload.durationMs as Any
                ]
                let _: EmptyResponse = try await APIService.shared.post(path: "/ads/impression", body: body)
            } catch {
                NavLog.debug("AdManager: impression tracking failed — \(error.localizedDescription)", category: .general)
            }
        }
    }

    // MARK: - Rewarded Ad Completion

    /// Reports a rewarded ad completion to the backend and refreshes balances.
    /// Returns the reward response (granted, reward type/amount, new balance).
    @discardableResult
    public func completeRewardedAd(placementId: String, impressionId: String, watchedFullDuration: Bool = true) async -> RewardedAdResponse? {
        // Record the impression locally
        recordImpression(placementId: placementId, impressionId: impressionId)

        do {
            let body: [String: Any] = [
                "placement_id": placementId,
                "impression_id": impressionId,
                "watched_full_duration": watchedFullDuration
            ]
            let response: RewardedAdResponse = try await APIService.shared.post(
                path: "/ads/rewarded/complete", body: body
            )

            // Refresh balances after reward grant
            if response.granted {
                await fetchBalances()
            }

            NavLog.debug("AdManager: rewarded ad completed — granted: \(response.granted), type: \(response.rewardType ?? "none")", category: .general)
            return response
        } catch {
            NavLog.debug("AdManager: rewarded completion failed — \(error.localizedDescription)", category: .general)
            return nil
        }
    }

    // MARK: - Consumable Balances

    /// Fetches the user's consumable balances from the backend.
    public func fetchBalances() async {
        do {
            let response: ConsumableBalances = try await APIService.shared.get(path: "/ads/balances")
            balances = response
        } catch {
            NavLog.debug("AdManager: balance fetch failed — \(error.localizedDescription)", category: .general)
        }
    }

    // MARK: - Convenience Helpers

    /// Returns the placement config for a given ID.
    public func placement(for placementId: String) -> AdPlacement? {
        placements[placementId]
    }

    /// Resets all local impression tracking. Called on logout.
    public func reset() {
        placements = [:]
        impressionLog = [:]
        lastImpressionDate = [:]
        balances = ConsumableBalances()
    }
}

// MARK: - Placement IDs (Constants)

public extension AdManager {
    /// Well-known placement IDs matching the backend configuration.
    enum PlacementID {
        public static let discoverNative = "discover_native"
        public static let reelFeedNative = "reel_feed_native"
        public static let chatBanner = "chat_banner"
        public static let inboxBanner = "inbox_banner"
        public static let profileInterstitial = "profile_interstitial"
        public static let matchInterstitial = "match_interstitial"
        public static let boostRewarded = "boost_rewarded"
        public static let superlikeRewarded = "superlike_rewarded"
        public static let extraLikesRewarded = "extra_likes_rewarded"
        public static let profileViewRewarded = "profile_view_rewarded"
    }
}
