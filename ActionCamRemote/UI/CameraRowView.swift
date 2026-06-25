import SwiftUI

struct CameraRowView: View {
    @Environment(CameraStore.self) private var store
    @State private var isShowingTelemetryDetails = false
    var camera: DiscoveredCamera
    var isShowingDiagnostics: Bool

    var body: some View {
        HStack(spacing: 0) {
            UnevenRoundedRectangle(
                topLeadingRadius: ACRDesign.cardCornerRadius,
                bottomLeadingRadius: ACRDesign.cardCornerRadius,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
                .fill(rowAccent)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        store.toggleSelection(for: camera)
                    } label: {
                        Image(systemName: camera.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectionColor)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.canSelectForBatch && !camera.isSelected)
                    .accessibilityLabel(camera.isSelected ? "Deselect \(camera.name)" : "Select \(camera.name)")

                    Text(camera.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.acrInk)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    StatusPill(text: camera.displayConnectionLabel, color: rowAccent)
                }

                HStack(alignment: .top, spacing: 0) {
                    Color.clear
                        .frame(width: leadingContentInset)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(cameraSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.acrMutedText)
                            .lineLimit(2)

                        if let unsupportedReason = camera.unsupportedReason {
                            Text(unsupportedReason)
                                .font(.caption)
                                .foregroundStyle(Color.acrMutedText)
                                .lineLimit(3)
                        }

                        #if DEBUG
                        if isShowingDiagnostics {
                            if camera.unsupportedReason == nil,
                               let detail = camera.connectionState.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.acrMutedText)
                                    .lineLimit(2)
                            }

                            if let diagnosticDetail = store.cameraDiagnosticDetail(for: camera),
                               shouldShowDiagnosticDetail {
                                Text(diagnosticDetail)
                                    .font(.caption)
                                    .foregroundStyle(Color.acrMutedText)
                                    .lineLimit(2)
                            }
                        }
                        #endif
                    }
                }
                .padding(.top, 2)

                if shouldShowMetricsOrActions {
                    HStack(alignment: .center, spacing: 0) {
                        Color.clear
                            .frame(width: leadingContentInset)

                        CameraTelemetryStrip(telemetry: telemetry, brand: camera.brand)

                        Spacer(minLength: 8)

                        actionControls
                    }
                    .padding(.top, 9)
                }

                if let telemetry, telemetry.detailSummaryLine != nil {
                    HStack(alignment: .top, spacing: 0) {
                        Color.clear.frame(width: leadingContentInset)
                        CameraTelemetryDisclosure(
                            telemetry: telemetry,
                            isExpanded: $isShowingTelemetryDetails
                        )
                    }
                    .padding(.top, 8)
                }
            }
            .padding(14)
        }
        .background(Color.acrSurface, in: RoundedRectangle(cornerRadius: ACRDesign.cardCornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ACRDesign.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ACRDesign.cardCornerRadius, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        }
    }

    private var selectionColor: Color {
        if camera.isSelected {
            return .acrReady
        }
        return camera.canSelectForBatch ? .secondary : Color.secondary.opacity(0.35)
    }

    private var rowAccent: Color {
        if camera.recordingState == .recording {
            return .acrRecord
        }
        return camera.connectionState.statusColor
    }

    private var rowStroke: Color {
        Color.acrLine.opacity(0.85)
    }

    private var leadingContentInset: CGFloat {
        46
    }

    private var shouldShowMetricsOrActions: Bool {
        hasPrimaryTelemetry || shouldShowActionControls
    }

    private var hasPrimaryTelemetry: Bool {
        guard let telemetry else { return false }
        return telemetry.batteryPercent != nil
            || telemetry.batteryBars != nil
            || (camera.brand != .dji && telemetry.remainingVideoSeconds != nil)
    }

    private var shouldShowActionControls: Bool {
        camera.canSwitchToVideoMode || camera.primaryRecordCommand != nil || camera.recordingState == .starting
    }

    @ViewBuilder
    private var actionControls: some View {
        HStack(spacing: 8) {
            if camera.canSwitchToVideoMode {
                CameraVideoModeButton(camera: camera)
            }

            if shouldShowRecordControl {
                CameraRecordButton(camera: camera)
            }
        }
    }

    private var shouldShowRecordControl: Bool {
        !camera.canSwitchToVideoMode
            && (camera.primaryRecordCommand != nil || camera.recordingState == .starting)
    }

    private var cameraSubtitle: String {
        var parts = [camera.brand.rawValue, camera.model.rawValue]

        if camera.isConnected {
            if let currentMode = camera.currentMode {
                parts.append(currentMode.rawValue)
            }
        }

        return parts.joined(separator: " · ")
    }

    private var telemetry: CameraTelemetry? {
        guard camera.isConnected else { return nil }
        return camera.telemetry
    }

    private var shouldShowDiagnosticDetail: Bool {
        camera.isKnownAction6 || camera.connectionState != .connected
    }
}

private struct CameraTelemetryStrip: View {
    var telemetry: CameraTelemetry?
    var brand: CameraBrand

    var body: some View {
        if !metricPills.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(metricPills, id: \.text) { item in
                        MetricPill(text: item.text, systemImage: item.systemImage)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(metricPills, id: \.text) { item in
                        MetricPill(text: item.text, systemImage: item.systemImage)
                    }
                }
            }
        }
    }

    private var metricPills: [(text: String, systemImage: String)] {
        guard let telemetry else { return [] }
        var items: [(text: String, systemImage: String)] = []

        if let batteryPercent = telemetry.batteryPercent {
            items.append(("Battery \(batteryPercent)%", batteryIcon(percent: batteryPercent)))
        } else if let batteryBars = telemetry.batteryBars {
            items.append(("Battery \(batteryBars)/4", batteryIcon(bars: batteryBars)))
        }

        if brand != .dji, let remainingVideoSeconds = telemetry.remainingVideoSeconds {
            items.append(("\(durationLabel(seconds: remainingVideoSeconds)) left", "record.circle"))
        }

        return items
    }

    private func durationLabel(seconds: UInt32) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(max(1, minutes))m"
    }

    private func batteryIcon(percent: Int) -> String {
        let boundedPercent = min(max(percent, 0), 100)

        switch boundedPercent {
        case 0...12:
            return "battery.0percent"
        case 13...37:
            return "battery.25percent"
        case 38...62:
            return "battery.50percent"
        case 63...87:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    private func batteryIcon(bars: Int) -> String {
        let boundedBars = min(max(bars, 0), 4)
        return batteryIcon(percent: boundedBars * 25)
    }
}

private struct CameraTelemetryDisclosure: View {
    var telemetry: CameraTelemetry
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let detailSummary = telemetry.detailSummaryLine {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Details")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.acrMutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Hide camera details" : "Show camera details")

                if isExpanded {
                    Text(detailSummary)
                        .font(.caption)
                        .foregroundStyle(Color.acrMutedText)
                        .lineLimit(3)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct CameraVideoModeButton: View {
    @Environment(CameraStore.self) private var store
    var camera: DiscoveredCamera

    var body: some View {
        Button {
            store.switchToVideo(camera)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "video")
                Text("Video")
            }
            .frame(minWidth: 78)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.acrReady)
        .fixedSize()
        .accessibilityLabel("Switch \(camera.name) to Video")
    }
}

private struct CameraRecordButton: View {
    @Environment(CameraStore.self) private var store
    var camera: DiscoveredCamera

    var body: some View {
        Group {
            if camera.recordingState == .recording {
                actionButton
                    .buttonStyle(.borderedProminent)
                    .tint(.acrInk)
            } else {
                actionButton
                    .buttonStyle(.bordered)
                    .tint(.acrRecord)
            }
        }
        .controlSize(.small)
        .disabled(camera.primaryRecordCommand == nil)
        .accessibilityLabel("\(camera.primaryRecordTitle) \(camera.name)")
        .fixedSize()
    }

    private var actionButton: some View {
        Button {
            performAction()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: camera.primaryRecordIcon)
                Text(camera.primaryRecordTitle)
            }
            .frame(minWidth: 82)
        }
    }

    private func performAction() {
        switch camera.primaryRecordCommand {
        case .startRecording:
            store.startRecording(camera)
        case .stopRecording:
            store.stopRecording(camera)
        case .toggleRecording, .setMode, .cycleMode, .applySetting, .keepAlive, nil:
            break
        }
    }
}
