import Foundation
import DeviceOpsCore

@MainActor
final class DeviceDetailViewModel: ObservableObject {
    @Published private(set) var device: DeviceDetailInfo?
    @Published private(set) var job: CommandJobInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: DeviceOpsServicing

    init(service: DeviceOpsServicing) {
        self.service = service
    }

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            device = try await service.fetchDevice(id: id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func sendCommand(deviceId: String, command: CommandType, payload: [String: String]? = nil) async {
        do {
            job = try await service.sendCommand(deviceId: deviceId, command: command, payload: payload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshJob() async {
        guard let job else { return }
        do {
            self.job = try await service.commandStatus(jobId: job.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
