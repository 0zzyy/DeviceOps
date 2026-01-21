import SwiftUI
import DeviceOpsCore

@main
struct DeviceOpsApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let service: DeviceOpsServicing
    let localAssistant = LocalAssistant()
    let remoteAssistant = RemoteAssistant()

    @Published var useRemoteAssistant = false

    init() {
        self.service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
    }
}
