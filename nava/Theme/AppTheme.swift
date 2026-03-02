import SwiftUI

// MARK: - NAVA Color System
struct AppColors {
    // Brand
    static let primary = Color(hex: "FF5864")
    static let primaryLight = Color(hex: "FF8A92")
    static let primaryDark = Color(hex: "E64550")
    static let secondary = Color(hex: "6A4C93")
    static let secondaryLight = Color(hex: "8B6BB0")
    static let accent = Color(hex: "845EC2")

    // Gradients
    static let gradientStart = Color(hex: "FF6B6B")
    static let gradientMiddle = Color(hex: "FF8E53")
    static let gradientEnd = Color(hex: "FE5196")
    static let brandGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Action colors
    static let like = Color(hex: "4CAF50")
    static let superLike = Color(hex: "00BCD4")
    static let pass = Color(hex: "9E9E9E")
    static let boost = Color(hex: "FFB800")
    static let rewind = Color(hex: "FF9800")

    // Status
    static let success = Color(hex: "00B894")
    static let error = Color(hex: "E74C3C")
    static let warning = Color(hex: "F39C12")
    static let info = Color(hex: "0984E3")
    static let online = Color(hex: "4CAF50")

    // Text
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "6C757D")
    static let textMuted = Color(hex: "ADB5BD")
    static let textWhite = Color.white

    // Borders
    static let border = Color(hex: "E9ECEF")
    static let borderLight = Color(hex: "F1F3F5")

    // Premium
    static let gold = Color(hex: "FFD700")
    static let premium = Color(hex: "845EC2")
    static let verified = Color(hex: "4ECDC4")
}

// MARK: - Adaptive Colors (Light/Dark)
extension Color {
    static let appBackground = Color("AppBackground", bundle: nil)
    static let appCard = Color("AppCard", bundle: nil)

    // Fallbacks that work without asset catalog colors
    static let warmWhite = Color(hex: "FFFBF8")
    static let deepNight = Color(hex: "1A1B2E")
    static let cardLight = Color.white
    static let cardDark = Color(hex: "2D3047")
}

// MARK: - Typography
struct AppTypography {
    static let h1: Font = .system(size: 32, weight: .bold)
    static let h2: Font = .system(size: 24, weight: .bold)
    static let h3: Font = .system(size: 20, weight: .semibold)
    static let h4: Font = .system(size: 18, weight: .semibold)
    static let body: Font = .system(size: 16, weight: .regular)
    static let bodyMedium: Font = .system(size: 16, weight: .medium)
    static let bodySmall: Font = .system(size: 14, weight: .regular)
    static let caption: Font = .system(size: 12, weight: .regular)
    static let button: Font = .system(size: 16, weight: .semibold)
    static let brand: Font = .system(size: 48, weight: .black)
    static let logo: Font = .system(size: 28, weight: .heavy)
}

// MARK: - Spacing
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 48
}

// MARK: - Border Radius
struct AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let round: CGFloat = 50
}

// MARK: - macOS Compatibility
#if os(macOS)
import AppKit

extension View {
    func navigationBarTitleDisplayMode(_ mode: Any) -> some View { self }
    func navigationBarHidden(_ hidden: Bool) -> some View { self }
}

extension NSColor {
    static let systemGray4 = NSColor.systemGray.withAlphaComponent(0.7)
    static let systemGray5 = NSColor.systemGray.withAlphaComponent(0.5)
    static let systemGray6 = NSColor.systemGray.withAlphaComponent(0.3)
    static let systemBackground = NSColor.windowBackgroundColor
}
#endif

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
