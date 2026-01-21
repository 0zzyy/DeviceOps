import SwiftUI
import DeviceOpsCore

struct DevicesView: View {
    private let service: DeviceOpsServicing
    @StateObject private var viewModel: DevicesViewModel
    @State private var selectedDevice: Device?

    init(service: DeviceOpsServicing) {
        self.service = service
        _viewModel = StateObject(wrappedValue: DevicesViewModel(service: service))
    }

    var body: some View {
        NavigationSplitView {
            VStack {
                searchAndFilters
                if viewModel.isLoading && viewModel.state.items.isEmpty {
                    LoadingStateView(title: "Loading devices…")
                } else if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await viewModel.load(page: 1) }
                    }
                } else if viewModel.state.items.isEmpty {
                    EmptyStateView(title: "No Devices", message: "Adjust filters or search to broaden results.")
                } else {
                    List(viewModel.state.items, selection: $selectedDevice) { device in
                        DeviceRow(device: device)
                            .onAppear { viewModel.loadNextPageIfNeeded(currentItem: device) }
                            .accessibilityIdentifier("device-row-\(device.id)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Devices")
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(deviceId: device.id, service: service)
            } else {
                EmptyStateView(title: "Select a Device", message: "Choose a device to view details.")
            }
        }
        .task {
            await viewModel.load(page: 1)
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.loadFirstPage()
        }
        .onChange(of: viewModel.selectedPlatform) { _ in
            viewModel.loadFirstPage()
        }
        .onChange(of: viewModel.selectedCompliance) { _ in
            viewModel.loadFirstPage()
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 8) {
            TextField("Search devices", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search devices")

            HStack {
                Picker("Platform", selection: $viewModel.selectedPlatform) {
                    Text("All Platforms").tag(Platform?.none)
                    ForEach(Platform.allCases) { platform in
                        Text(platform.rawValue).tag(Platform?.some(platform))
                    }
                }
                Picker("Compliance", selection: $viewModel.selectedCompliance) {
                    Text("All Status").tag(ComplianceStatus?.none)
                    ForEach(ComplianceStatus.allCases) { status in
                        Text(status.rawValue.capitalized).tag(ComplianceStatus?.some(status))
                    }
                }
            }
            .pickerStyle(.segmented)
        }
        .padding([.horizontal, .top])
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                Text("\(device.platform.rawValue) • \(device.osVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(device.compliance.rawValue.capitalized)
                .font(.caption)
                .padding(6)
                .background(device.compliance == .compliant ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
    }
}
