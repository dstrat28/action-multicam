import SwiftUI
import UIKit

extension Color {
    static let acrInk = Color.adaptive(
        light: UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.94, blue: 0.97, alpha: 1)
    )
    static let acrAppBackground = Color.adaptive(
        light: UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 1)
    )
    static let acrSurface = Color.adaptive(
        light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1)
    )
    static let acrInsetSurface = Color.adaptive(
        light: UIColor(red: 0.91, green: 0.94, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1)
    )
    static let acrLine = Color.adaptive(
        light: UIColor(red: 0.79, green: 0.84, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.27, blue: 0.34, alpha: 1)
    )
    static let acrMutedText = Color.adaptive(
        light: UIColor(red: 0.39, green: 0.45, blue: 0.52, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.68, blue: 0.75, alpha: 1)
    )
    static let acrRecord = Color(red: 0.90, green: 0.12, blue: 0.16)
    static let acrReady = Color(red: 0.02, green: 0.58, blue: 0.43)
    static let acrAvailable = Color(red: 0.10, green: 0.45, blue: 0.92)
    static let acrWarning = Color(red: 0.93, green: 0.56, blue: 0.12)
    static let acrAccent = Color(red: 0.30, green: 0.42, blue: 0.96)
    static let acrDJI = Color(red: 0.23, green: 0.45, blue: 0.96)
    static let acrGoPro = Color(red: 0.00, green: 0.58, blue: 0.66)
    static let acrCommandTop = Color.adaptive(
        light: UIColor(red: 0.09, green: 0.14, blue: 0.21, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.18, blue: 0.26, alpha: 1)
    )
    static let acrCommandBottom = Color.adaptive(
        light: UIColor(red: 0.06, green: 0.28, blue: 0.38, alpha: 1),
        dark: UIColor(red: 0.06, green: 0.21, blue: 0.30, alpha: 1)
    )

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
    static let insetCornerRadius: CGFloat = 14
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
    }

    func acrInsetPanel(fill: Color = .acrInsetSurface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: ACRDesign.insetCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ACRDesign.insetCornerRadius, style: .continuous)
                    .stroke(Color.acrLine.opacity(0.55), lineWidth: 1)
            }
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

struct MetricPill: View {
    var text: String
    var systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.acrInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.acrInsetSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.acrLine.opacity(0.65), lineWidth: 1)
            }
            .lineLimit(1)
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

extension CameraConnectionState {
    var statusColor: Color {
        switch self {
        case .connected:
            .acrReady
        case .discovered:
            .acrAvailable
        case .connecting, .reconnecting:
            .acrWarning
        case .unsupported, .failed, .disconnected:
            .secondary
        }
    }
}

extension CameraRecordingState {
    var statusColor: Color {
        switch self {
        case .recording:
            .acrRecord
        case .starting:
            .acrWarning
        case .ready, .stopped:
            .acrReady
        case .unknown, .unavailable:
            .secondary
        }
    }
}
