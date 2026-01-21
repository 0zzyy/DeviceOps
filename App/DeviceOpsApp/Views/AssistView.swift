import SwiftUI
import DeviceOpsCore

struct AssistView: View {
    @EnvironmentObject private var container: AppContainer
    private let service: DeviceOpsServicing
    private let localAssistant: AIAssistantProviding
    private let remoteAssistant: AIAssistantProviding
    @StateObject private var viewModel: AssistViewModel
    @State private var selectedDevices: Set<String> = []

    init(service: DeviceOpsServicing, localAssistant: AIAssistantProviding, remoteAssistant: AIAssistantProviding) {
        self.service = service
        self.localAssistant = localAssistant
        self.remoteAssistant = remoteAssistant
        _viewModel = StateObject(wrappedValue: AssistViewModel(service: service, assistant: localAssistant))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable remote assistant (opt-in)", isOn: $container.useRemoteAssistant)
                    .toggleStyle(.switch)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    LoadingStateView(title: "Loading assist data…")
                } else if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await viewModel.loadDevices() }
                    }
                } else {
                    List(viewModel.devices, selection: $selectedDevices) { device in
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.platform.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 220)

                    Button("Summarize First Device") {
                        if let device = viewModel.devices.first {
                            viewModel.summarize(device: device)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    if !viewModel.summary.isEmpty {
                        Text(viewModel.summary)
                            .padding(.horizontal)
                            .accessibilityLabel("Summary")
                    }

                    Button("Generate Runbook") {
                        let selected = viewModel.devices.filter { selectedDevices.contains($0.id) }
                        viewModel.generateRunbook(selected: selected)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    if !viewModel.runbook.isEmpty {
                        ScrollView {
                            Text(viewModel.runbook)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Assist")
        }
        .task {
            viewModel.updateAssistant(container.useRemoteAssistant ? remoteAssistant : localAssistant)
            await viewModel.loadDevices()
        }
        .onChange(of: container.useRemoteAssistant) { useRemote in
            viewModel.updateAssistant(useRemote ? remoteAssistant : localAssistant)
        }
    }
}
