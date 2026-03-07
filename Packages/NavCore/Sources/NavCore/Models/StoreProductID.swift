import Foundation

// MARK: - Store Product Identifiers

public enum StoreProductID: String, CaseIterable {
    // Subscriptions (auto-renewable)
    case goldMonthly = "com.nava.gold_monthly"
    case platinumMonthly = "com.nava.platinum_monthly"
    case ultraMonthly = "com.nava.ultra_monthly"

    // Consumables
    case boost1 = "com.nava.boost_1"
    case boost5 = "com.nava.boost_5"
    case superLike5 = "com.nava.super_like_5"
    case spotlight1hr = "com.nava.spotlight_1hr"

    /// Maps to backend product_id for server-side validation
    public var backendProductID: String {
        switch self {
        case .goldMonthly: return "gold_monthly"
        case .platinumMonthly: return "platinum_monthly"
        case .ultraMonthly: return "ultra_monthly"
        case .boost1: return "boost_1"
        case .boost5: return "boost_5"
        case .superLike5: return "super_like_5"
        case .spotlight1hr: return "spotlight_1hr"
        }
    }
}
