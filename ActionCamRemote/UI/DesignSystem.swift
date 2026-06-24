import SwiftUI

extension Color {
    static let acrInk = Color(red: 0.08, green: 0.09, blue: 0.10)
    static let acrPanel = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let acrLine = Color(red: 0.82, green: 0.84, blue: 0.84)
    static let acrRecord = Color(red: 0.84, green: 0.08, blue: 0.10)
    static let acrReady = Color(red: 0.08, green: 0.45, blue: 0.28)
    static let acrWarning = Color(red: 0.82, green: 0.48, blue: 0.10)
    static let acrDJI = Color(red: 0.00, green: 0.32, blue: 0.95)
    static let acrGoPro = Color(red: 0.00, green: 0.52, blue: 0.45)
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
