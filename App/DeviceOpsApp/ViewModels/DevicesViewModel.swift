import Foundation
import DeviceOpsCore

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published private(set) var state = PaginationState<Device>()
    @Published var searchText: String = ""
    @Published var selectedPlatform: Platform? = nil
    @Published var selectedCompliance: ComplianceStatus? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: DeviceOpsServicing
    private var searchTask: Task<Void, Never>?

    init(service: DeviceOpsServicing) {
        self.service = service
    }

    func loadFirstPage() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.load(page: 1)
        }
    }

    func loadNextPageIfNeeded(currentItem: Device?) {
        guard let currentItem = currentItem else { return }
        let thresholdIndex = state.items.index(state.items.endIndex, offsetBy: -5, limitedBy: state.items.startIndex) ?? state.items.startIndex
        if state.items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
            Task { await load(page: state.page + 1) }
        }
    }

    func load(page: Int) async {
        guard !isLoading else { return }
        guard page == 1 || state.canLoadMore else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.fetchDevices(
                page: page,
                query: searchText.isEmpty ? nil : searchText,
                platform: selectedPlatform,
                compliance: selectedCompliance
            )
            state.appendPage(result)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
