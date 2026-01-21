import Foundation
import DeviceOpsCore

@MainActor
final class SoftwareCatalogViewModel: ObservableObject {
    @Published private(set) var state = PaginationState<Software>()
    @Published var selectedPlatform: Platform? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastJob: CommandJobInfo?

    private let service: DeviceOpsServicing

    init(service: DeviceOpsServicing) {
        self.service = service
    }

    func load(page: Int) async {
        guard !isLoading else { return }
        guard page == 1 || state.canLoadMore else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.fetchSoftware(page: page, platform: selectedPlatform)
            state.appendPage(result)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadFirstPage() {
        Task { await load(page: 1) }
    }

    func loadNextPageIfNeeded(currentItem: Software?) {
        guard let currentItem = currentItem else { return }
        let thresholdIndex = state.items.index(state.items.endIndex, offsetBy: -5, limitedBy: state.items.startIndex) ?? state.items.startIndex
        if state.items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
            Task { await load(page: state.page + 1) }
        }
    }

    func requestInstall(softwareId: String) async {
        do {
            lastJob = try await service.requestInstall(softwareId: softwareId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
