import SwiftUI
import UIKit

extension Color {
    static let acrInk = Color.adaptive(
        light: UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.26, blue: 0.28, alpha: 1)
    )
    static let acrAppBackground = Color.adaptive(
        light: UIColor(red: 0.95, green: 0.96, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)
    )
    static let acrSurface = Color.adaptive(
        light: UIColor(red: 1.00, green: 1.00, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
    )
    static let acrInsetSurface = Color.adaptive(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
    )
    static let acrLine = Color.adaptive(
        light: UIColor(red: 0.82, green: 0.84, blue: 0.84, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.30, blue: 0.33, alpha: 1)
    )
    static let acrRecord = Color(red: 0.84, green: 0.08, blue: 0.10)
    static let acrReady = Color(red: 0.08, green: 0.45, blue: 0.28)
    static let acrWarning = Color(red: 0.82, green: 0.48, blue: 0.10)
    static let acrDJI = Color(red: 0.00, green: 0.32, blue: 0.95)
    static let acrGoPro = Color(red: 0.00, green: 0.52, blue: 0.45)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum ACRDesign {
    static let cardCornerRadius: CGFloat = 14
    static let insetCornerRadius: CGFloat = 12
}

extension View {
    func acrCard(
        fill: Color = .acrSurface,
        stroke: Color = .acrLine,
        lineWidth: CGFloat = 1
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: ACRDesign.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ACRDesign.cardCornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: lineWidth)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    func acrInsetPanel(fill: Color = .acrInsetSurface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: ACRDesign.insetCornerRadius, style: .continuous))
    }
}

extension CameraBrand {
    var badgeColor: Color {
        switch self {
        case .gopro:
            .acrGoPro
        case .dji:
            .acrDJI
        case .unknown:
            .secondary
        }
    }
}

struct StatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel(text)
    }
}

struct IconActionButton: View {
    var title: String
    var systemImage: String
    var role: ButtonRole?
    var action: () -> Void

    init(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
