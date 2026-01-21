import Foundation
import DeviceOpsCore

@MainActor
final class AssistViewModel: ObservableObject {
    @Published private(set) var devices: [DeviceDetailInfo] = []
    @Published private(set) var runbook: String = ""
    @Published private(set) var summary: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: DeviceOpsServicing
    private var assistant: AIAssistantProviding

    init(service: DeviceOpsServicing, assistant: AIAssistantProviding) {
        self.service = service
        self.assistant = assistant
    }

    func updateAssistant(_ assistant: AIAssistantProviding) {
        self.assistant = assistant
    }

    func loadDevices() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await service.fetchDevices(page: 1, query: nil, platform: nil, compliance: nil)
            let detail = try await withThrowingTaskGroup(of: DeviceDetailInfo.self) { group in
                for device in page.items.prefix(5) {
                    group.addTask {
                        try await self.service.fetchDevice(id: device.id)
                    }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
            devices = detail
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func summarize(device: DeviceDetailInfo) {
        summary = assistant.summarizeCompliance(for: device)
    }

    func generateRunbook(selected: [DeviceDetailInfo]) {
        runbook = assistant.generateRunbook(for: selected)
    }
}
