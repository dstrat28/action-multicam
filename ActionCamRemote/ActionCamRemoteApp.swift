import SwiftUI

@main
struct ActionCamRemoteApp: App {
    @State private var store = CameraStore()

    var body: some Scene {
        WindowGroup {
            CameraDashboardView()
                .environment(store)
        }
    }
}
