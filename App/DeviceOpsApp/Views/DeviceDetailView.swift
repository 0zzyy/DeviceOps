import SwiftUI
import DeviceOpsCore

struct DeviceDetailView: View {
    let deviceId: String
    @StateObject private var viewModel: DeviceDetailViewModel

    init(deviceId: String, service: DeviceOpsServicing) {
        self.deviceId = deviceId
        _viewModel = StateObject(wrappedValue: DeviceDetailViewModel(service: service))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading device…")
            } else if let message = viewModel.errorMessage {
                ErrorStateView(message: message) {
                    Task { await viewModel.load(id: deviceId) }
                }
            } else if let device = viewModel.device {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        identitySection(device)
                        complianceSection(device)
                        installedAppsSection(device)
                        actionsSection(device)
                        jobSection
                    }
                    .padding()
                }
            } else {
                EmptyStateView(title: "Device not found", message: "Select a valid device.")
            }
        }
        .navigationTitle("Device Detail")
        .task {
            await viewModel.load(id: deviceId)
        }
    }

    private func identitySection(_ device: DeviceDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Identity")
                .font(.headline)
            InfoRow(title: "Name", value: device.name)
            InfoRow(title: "Platform", value: device.platform.rawValue)
            InfoRow(title: "OS Version", value: device.osVersion)
            InfoRow(title: "Serial", value: device.serialNumber)
            InfoRow(title: "Last Check-in", value: device.lastCheckIn.formatted())
        }
    }

    private func complianceSection(_ device: DeviceDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compliance Signals")
                .font(.headline)
            InfoRow(title: "FileVault", value: device.complianceSignals.fileVaultEnabled ? "Enabled" : "Disabled")
            InfoRow(title: "Passcode", value: device.complianceSignals.passcodeEnabled ? "Enabled" : "Disabled")
            InfoRow(title: "EDR", value: device.complianceSignals.edrPresent ? "Present" : "Missing")
            InfoRow(title: "Risky Apps", value: "\(device.complianceSignals.riskyAppsCount)")
        }
    }

    private func installedAppsSection(_ device: DeviceDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installed Apps")
                .font(.headline)
            ForEach(device.installedApps) { app in
                HStack {
                    VStack(alignment: .leading) {
                        Text(app.name)
                        Text("v\(app.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func actionsSection(_ device: DeviceDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MDM Actions")
                .font(.headline)
            ActionButton(title: "Query Device Information", identifier: "action-query-device") {
                Task { await viewModel.sendCommand(deviceId: device.id, command: .queryDeviceInformation) }
            }
            ActionButton(title: "Query Security Info", identifier: "action-query-security") {
                Task { await viewModel.sendCommand(deviceId: device.id, command: .querySecurityInfo) }
            }
            ActionButton(title: "Query Installed Apps", identifier: "action-query-apps") {
                Task { await viewModel.sendCommand(deviceId: device.id, command: .queryInstalledApps) }
            }
            ActionButton(title: "Install Application", identifier: "action-install-app") {
                Task { await viewModel.sendCommand(deviceId: device.id, command: .installApplication, payload: ["appId": "S1"]) }
            }
        }
    }

    private var jobSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command Status")
                .font(.headline)
            if let job = viewModel.job {
                InfoRow(title: "Job", value: job.id)
                InfoRow(title: "Status", value: job.status.rawValue)
                if let reason = job.failureReason {
                    InfoRow(title: "Failure", value: reason)
                }
                Button("Refresh Status") {
                    Task { await viewModel.refreshJob() }
                }
                .accessibilityIdentifier("job-refresh")
                Text(job.status.rawValue)
                    .font(.caption)
                    .accessibilityIdentifier("job-status")
            } else {
                Text("No command activity yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ActionButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
