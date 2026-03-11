import SwiftUI

/// A reusable error/offline banner that slides in from the top.
/// Supports retry actions and auto-dismiss.
public struct ErrorBanner: View {
    public enum Style {
        case offline
        case error(String)
        case warning(String)
    }

    let style: Style
    let retryAction: (() -> Void)?

    public init(style: Style, retryAction: (() -> Void)? = nil) {
        self.style = style
        self.retryAction = retryAction
    }

    private var icon: String {
        switch style {
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        }
    }

    private var message: String {
        switch style {
        case .offline: return "No internet connection"
        case .error(let msg): return msg
        case .warning(let msg): return msg
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .offline: return Color(hex: "2D2D3A")
        case .error: return Color(hex: "3A2020")
        case .warning: return Color(hex: "3A3520")
        }
    }

    private var iconColor: Color {
        switch style {
        case .offline: return Color(hex: "A8D8EA")
        case .error: return Color(hex: "FF6B6B")
        case .warning: return Color(hex: "FFD93D")
        }
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)

            Spacer()

            if let retryAction {
                Button {
                    retryAction()
                } label: {
                    Text("Retry")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(iconColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// View modifier that adds an offline banner at the top of any view.
public struct OfflineBannerModifier: ViewModifier {
    let isOffline: Bool

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isOffline {
                ErrorBanner(style: .offline)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOffline)
    }
}

public extension View {
    func offlineBanner(isOffline: Bool) -> some View {
        modifier(OfflineBannerModifier(isOffline: isOffline))
    }
}
