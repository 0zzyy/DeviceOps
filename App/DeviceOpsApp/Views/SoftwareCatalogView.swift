import SwiftUI
import DeviceOpsCore

struct SoftwareCatalogView: View {
    @StateObject private var viewModel: SoftwareCatalogViewModel

    init(service: DeviceOpsServicing) {
        _viewModel = StateObject(wrappedValue: SoftwareCatalogViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Platform", selection: $viewModel.selectedPlatform) {
                    Text("All Platforms").tag(Platform?.none)
                    ForEach(Platform.allCases) { platform in
                        Text(platform.rawValue).tag(Platform?.some(platform))
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.isLoading && viewModel.state.items.isEmpty {
                    LoadingStateView(title: "Loading software…")
                } else if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await viewModel.load(page: 1) }
                    }
                } else if viewModel.state.items.isEmpty {
                    EmptyStateView(title: "No Software", message: "Adjust the platform filter to find packages.")
                } else {
                    List(viewModel.state.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text("\(item.platform.rawValue) • v\(item.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Request Install") {
                                Task { await viewModel.requestInstall(softwareId: item.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .onAppear { viewModel.loadNextPageIfNeeded(currentItem: item) }
                    }
                }

                if let job = viewModel.lastJob {
                    HStack {
                        Text("Job \(job.id) • \(job.status.rawValue)")
                            .font(.caption)
                        Spacer()
                    }
                    .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("Software Catalog")
        }
        .task {
            await viewModel.load(page: 1)
        }
        .onChange(of: viewModel.selectedPlatform) { _ in
            viewModel.loadFirstPage()
        }
    }
}
