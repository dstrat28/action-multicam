import SwiftUI
import UIKit

struct CameraDashboardView: View {
    @Environment(CameraStore.self) private var store
    @State private var isManagingCameras = false
    @State private var manageCameraDetent: PresentationDetent = .large
    @State private var isShowingDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ControlDeckView()
                    CameraListView(isShowingDiagnostics: activeDiagnosticsVisibility) {
                        isManagingCameras = true
                    }
                    #if DEBUG
                    DiagnosticsView(isExpanded: $isShowingDiagnostics)
                    #endif
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.acrAppBackground, Color.acrInsetSurface.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Action Cam Remote")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        store.selectAllSupported()
                    } label: {
                        Image(systemName: "checklist.checked")
                    }
                    .accessibilityLabel("Select supported cameras")
                }
            }
            .sheet(isPresented: $isManagingCameras) {
                NavigationStack {
                    PairingView()
                }
                .presentationDetents([.large], selection: $manageCameraDetent)
            }
        }
    }

    private var activeDiagnosticsVisibility: Bool {
        #if DEBUG
        isShowingDiagnostics
        #else
        false
        #endif
    }
}

private struct ControlDeckView: View {
    @Environment(CameraStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text("Multicam Control")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    SessionCountPill(
                        text: "\(store.selectedControllableCameras.count) selected",
                        systemImage: "checkmark.circle"
                    )
                    SessionCountPill(
                        text: "\(store.connectedCameras.count) connected",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                }
            }

            HStack(spacing: 12) {
                if store.canStopMulticamRecording {
                    MulticamCommandButton(
                        title: "Stop All Cameras",
                        systemImage: "stop.circle",
                        color: .acrRecord,
                        isEnabled: true
                    ) {
                        store.stopMulticamRecording()
                    }
                } else {
                    MulticamCommandButton(
                        title: startButtonTitle,
                        systemImage: "record.circle",
                        color: .acrReady,
                        isEnabled: store.canStartMulticamRecording
                    ) {
                        store.startMulticamRecording()
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [.acrCommandTop, .acrCommandBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var startButtonTitle: String {
        guard !store.controllableRecordCameras.isEmpty,
              store.selectedControllableCameras.count == store.controllableRecordCameras.count else {
            return "Start Selected Cameras"
        }

        return "Start All Cameras"
    }
}

private struct MulticamCommandButton: View {
    var title: String
    var systemImage: String
    var color: Color
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.64))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(buttonFill, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isEnabled ? 0.12 : 0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private var buttonFill: Color {
        isEnabled ? color : Color.white.opacity(0.10)
    }
}

private struct SessionCountPill: View {
    var text: String
    var systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .lineLimit(1)
    }
}

private struct CameraListView: View {
    @Environment(CameraStore.self) private var store
    var isShowingDiagnostics: Bool
    var onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cameras")
                    .font(.title3.weight(.bold))
                Spacer()
                Button {
                    onManage()
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.acrAccent)
            }

            if store.pairedCameras.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Previously connected cameras will show here")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .padding(.horizontal)
                .acrCard(fill: Color.acrSurface.opacity(0.78), stroke: Color.acrLine.opacity(0.8))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.pairedCameras) { camera in
                        CameraRowView(
                            camera: camera,
                            isShowingDiagnostics: isShowingDiagnostics
                        )
                    }
                }
            }
        }
    }
}

private struct PairingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CameraStore.self) private var store

    var body: some View {
        List {
            Section("Discovered") {
                if store.pairingCameras.isEmpty {
                    ContentUnavailableView(
                        "No Cameras Found",
                        systemImage: "camera.badge.ellipsis",
                        description: Text("Put a camera in pairing mode, then scan.")
                    )
                } else {
                    ForEach(store.pairingCameras) { camera in
                        PairingCameraRow(camera: camera)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.acrAppBackground)
        .navigationTitle("Manage Cameras")
        .onAppear {
            store.setPairingModeActive(true)
            store.startScanning()
        }
        .onDisappear {
            store.setPairingModeActive(false)
            if store.pairedCameras.isEmpty {
                store.stopScanning()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct PairingCameraRow: View {
    @Environment(CameraStore.self) private var store
    var camera: DiscoveredCamera

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(camera.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("\(camera.brand.rawValue) · \(camera.model.rawValue) · \(camera.connectionState.label)")
                        .font(.subheadline)
                        .foregroundStyle(Color.acrMutedText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if camera.isPaired {
                        Button(role: .destructive) {
                            store.remove(camera)
                        } label: {
                            Text("Remove")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                    } else if camera.unsupportedReason != nil {
                        Button {
                        } label: {
                            Text("Unsupported")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                        .disabled(true)
                    } else {
                        Button {
                            store.connect(camera)
                        } label: {
                            Text(pairButtonTitle)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .fixedSize()
                        .disabled(camera.connectionState == .connecting || camera.needsGoProPairingMode)
                    }
                }
            }

            if let detail = pairingDetail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.acrMutedText)
            }
        }
        .padding(.vertical, 4)
    }

    private var pairButtonTitle: String {
        if camera.needsGoProPairingMode {
            return "Pairing Mode"
        }
        return camera.connectionState == .connecting ? "Pairing" : "Pair"
    }

    private var pairingDetail: String? {
        if camera.needsGoProPairingMode {
            return "Put the GoPro in pairing mode from the camera UI, then tap Pair again."
        }

        guard camera.unsupportedReason == nil else { return nil }
        return camera.connectionState.detail
    }
}

private struct DiagnosticsView: View {
    @Environment(CameraStore.self) private var store
    @Binding var isExpanded: Bool
    @State private var didCopyDiagnostics = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        UIPasteboard.general.string = store.diagnosticsText
                        didCopyDiagnostics = true
                    } label: {
                        Label(didCopyDiagnostics ? "Copied" : "Copy Diagnostics", systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }

                DJIStatusProbeView()
                RecentResultsView()
                EventLogView()
            }
            .padding(.top, 10)
        } label: {
            Label("Diagnostics", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Color.acrInk)
        }
        .padding()
        .acrCard(fill: Color.acrSurface.opacity(0.78), stroke: Color.acrLine.opacity(0.9))
    }
}

private struct DJIStatusProbeView: View {
    @Environment(CameraStore.self) private var store

    var body: some View {
        let cameras = store.connectedCameras.filter { $0.brand == .dji }

        if !cameras.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("DJI Status Probe")
                    .font(.headline)

                ForEach(cameras) { camera in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(camera.name)
                                .font(.subheadline.weight(.semibold))
                            Text("Tap after setting the camera mode on-device.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            store.probeStatus(camera)
                        } label: {
                            Label("Probe", systemImage: "waveform.path.ecg")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .acrInsetPanel()
                }
            }
        }
    }
}

private struct RecentResultsView: View {
    @Environment(CameraStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Command Results")
                .font(.headline)

            if store.commandResults.isEmpty {
                Text("No commands sent yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .acrInsetPanel()
            } else {
                ForEach(store.commandResults.prefix(6)) { result in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: result.status))
                            .foregroundStyle(color(for: result.status))
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.cameraName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(result.command.label): \(result.message)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .acrInsetPanel()
                }
            }
        }
    }

    private func icon(for status: CameraCommandStatus) -> String {
        switch status {
        case .queued, .sent:
            "checkmark.circle.fill"
        case .skipped:
            "minus.circle.fill"
        case .unsupported:
            "exclamationmark.triangle.fill"
        case .failed:
            "xmark.circle.fill"
        }
    }

    private func color(for status: CameraCommandStatus) -> Color {
        switch status {
        case .queued, .sent:
            .acrReady
        case .skipped:
            .secondary
        case .unsupported:
            .acrWarning
        case .failed:
            .acrRecord
        }
    }
}

private struct EventLogView: View {
    @Environment(CameraStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bluetooth Log")
                .font(.headline)

            if store.eventLog.isEmpty {
                Text("Discovery and protocol messages will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .acrInsetPanel()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.eventLog.prefix(30), id: \.self) { line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .acrInsetPanel()
            }
        }
    }
}

#Preview {
    CameraDashboardView()
        .environment(CameraStore.preview)
}
