import Foundation

extension CameraStore {
    func loadDemoCameras() {
        cameras = Self.demoCandidates.map { makeCamera in
            var camera = makeCamera()
            if camera.supportsBatchRecord {
                camera.connectionState = .connected
                camera.recordingState = .stopped
                camera.isPaired = true
                camera.isSelected = true
            }
            return camera
        }
        eventLog = [
            "[9:41:02 AM] GoPro HERO13: command characteristic is ready.",
            "[9:40:58 AM] DJI Action 6: discovered 4 candidate services.",
            "[9:40:54 AM] Simulator demo mode loaded sample cameras."
        ]
    }

    static var preview: CameraStore {
        let store = CameraStore(demoMode: false)
        store.loadDemoCameras()
        return store
    }
}
