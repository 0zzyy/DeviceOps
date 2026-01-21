import Foundation
import DeviceOpsCore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var summary: FleetSummary?
    @Published private(set) var recentDevices: [Device] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: DeviceOpsServicing

    init(service: DeviceOpsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await service.fetchDevices(page: 1, query: nil, platform: nil, compliance: nil)
            let platformCounts = Dictionary(grouping: page.items, by: { $0.platform })
                .mapValues { $0.count }
            let compliantCount = page.items.filter { $0.compliance == .compliant }.count
            let noncompliantCount = page.items.filter { $0.compliance == .noncompliant }.count
            let encryptionIssues = page.items.filter { $0.platform == .macOS && $0.compliance == .noncompliant }.count
            let highRisk = page.items.filter { $0.compliance == .noncompliant }.prefix(10).count
            summary = FleetSummary(
                platformCounts: platformCounts,
                compliantCount: compliantCount,
                noncompliantCount: noncompliantCount,
                encryptionIssues: encryptionIssues,
                highRiskCount: highRisk
            )
            recentDevices = Array(page.items.prefix(6))
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
