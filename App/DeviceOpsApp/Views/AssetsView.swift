import SwiftUI
import DeviceOpsCore

struct AssetsView: View {
    @StateObject private var viewModel: AssetsViewModel

    init(service: DeviceOpsServicing) {
        _viewModel = StateObject(wrappedValue: AssetsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search assets", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                if viewModel.isLoading && viewModel.state.items.isEmpty {
                    LoadingStateView(title: "Loading assets…")
                } else if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await viewModel.load(page: 1) }
                    }
                } else if viewModel.state.items.isEmpty {
                    EmptyStateView(title: "No Assets", message: "Start the mock server to load assets.")
                } else {
                    List(viewModel.state.items) { asset in
                        VStack(alignment: .leading) {
                            Text(asset.assetTag)
                                .font(.headline)
                            Text("Serial: \(asset.serialNumber) • \(asset.lifecycleState)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("User: \(asset.assignedUser) • \(asset.costCenter)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .onAppear { viewModel.loadNextPageIfNeeded(currentItem: asset) }
                    }
                }
            }
            .navigationTitle("Assets")
        }
        .task {
            await viewModel.load(page: 1)
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.loadFirstPage()
        }
    }
}
