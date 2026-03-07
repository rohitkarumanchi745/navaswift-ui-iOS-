import SwiftUI

// MARK: - NAVA Color System
public struct AppColors {
    // Brand
    public static let primary = Color(hex: "FF5864")
    public static let primaryLight = Color(hex: "FF8A92")
    public static let primaryDark = Color(hex: "E64550")
    public static let secondary = Color(hex: "6A4C93")
    public static let secondaryLight = Color(hex: "8B6BB0")
    public static let accent = Color(hex: "845EC2")

    // Gradients
    public static let gradientStart = Color(hex: "FF6B6B")
    public static let gradientMiddle = Color(hex: "FF8E53")
    public static let gradientEnd = Color(hex: "FE5196")
    public static let brandGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Action colors
    public static let like = Color(hex: "4CAF50")
    public static let superLike = Color(hex: "00BCD4")
    public static let pass = Color(hex: "9E9E9E")
    public static let boost = Color(hex: "FFB800")
    public static let rewind = Color(hex: "FF9800")

    // Status
    public static let success = Color(hex: "00B894")
    public static let error = Color(hex: "E74C3C")
    public static let warning = Color(hex: "F39C12")
    public static let info = Color(hex: "0984E3")
    public static let online = Color(hex: "4CAF50")

    // Text
    public static let textPrimary = Color(hex: "1A1A2E")
    public static let textSecondary = Color(hex: "6C757D")
    public static let textMuted = Color(hex: "ADB5BD")
    public static let textWhite = Color.white

    // Borders
    public static let border = Color(hex: "E9ECEF")
    public static let borderLight = Color(hex: "F1F3F5")

    // Premium
    public static let gold = Color(hex: "FFD700")
    public static let premium = Color(hex: "845EC2")
    public static let verified = Color(hex: "4ECDC4")

    // Surfaces
    public static let background = Color(hex: "F8F9FA")
    public static let cardBackground = Color.white
    public static let inputBackground = Color(hex: "F8FAFC")

    // Edit Profile accent (indigo)
    public static let editAccent = Color(hex: "667EEA")
    public static let editAccentLight = Color(hex: "667EEA").opacity(0.1)

    // Verification green
    public static let verifyGreen = Color(hex: "5F7A66")
    public static let verifyGreenLight = Color(hex: "5F7A66").opacity(0.1)

    // Verification page background
    public static let peachBackground = Color(hex: "F3D9D1")

    public init() {}
}

// MARK: - Adaptive Colors (Light/Dark)
public extension Color {
    static let warmWhite = Color(hex: "FFFBF8")
    static let deepNight = Color(hex: "1A1B2E")
    static let cardLight = Color.white
    static let cardDark = Color(hex: "2D3047")
}

// MARK: - Typography
public struct AppTypography {
    public static let h1: Font = .system(size: 32, weight: .bold)
    public static let h2: Font = .system(size: 24, weight: .bold)
    public static let h3: Font = .system(size: 20, weight: .semibold)
    public static let h4: Font = .system(size: 18, weight: .semibold)
    public static let body: Font = .system(size: 16, weight: .regular)
    public static let bodyMedium: Font = .system(size: 16, weight: .medium)
    public static let bodySmall: Font = .system(size: 14, weight: .regular)
    public static let caption: Font = .system(size: 12, weight: .regular)
    public static let button: Font = .system(size: 16, weight: .semibold)
    public static let brand: Font = .system(size: 48, weight: .black)
    public static let logo: Font = .system(size: 28, weight: .heavy)
    public init() {}
}

// MARK: - Spacing
public struct AppSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let xxxl: CGFloat = 32
    public static let xxxxl: CGFloat = 48
    public init() {}
}

// MARK: - Border Radius
public struct AppRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let round: CGFloat = 50
    public init() {}
}

// MARK: - macOS Compatibility
#if os(macOS)
import AppKit

public extension View {
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
public extension Color {
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
