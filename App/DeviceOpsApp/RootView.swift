import SwiftUI
import DeviceOpsCore

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            DashboardView(service: container.service)
                .tabItem { Label("Dashboard", systemImage: "speedometer") }
            DevicesView(service: container.service)
                .tabItem { Label("Devices", systemImage: "laptopcomputer") }
            AssetsView(service: container.service)
                .tabItem { Label("Assets", systemImage: "shippingbox") }
            SoftwareCatalogView(service: container.service)
                .tabItem { Label("Software", systemImage: "square.stack.3d.up") }
            AssistView(
                service: container.service,
                localAssistant: container.localAssistant,
                remoteAssistant: container.remoteAssistant
            )
            .tabItem { Label("Assist", systemImage: "sparkles") }
        }
    }
}
