import SwiftUI
import DeviceOpsCore

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(service: DeviceOpsServicing) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingStateView(title: "Loading fleet summary…")
                } else if let message = viewModel.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await viewModel.load() }
                    }
                } else if let summary = viewModel.summary {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            summaryCards(summary)
                            recentActivity
                        }
                        .padding()
                    }
                } else {
                    EmptyStateView(title: "No Data", message: "Start the mock server to load fleet health.")
                }
            }
            .navigationTitle("Dashboard")
        }
        .task {
            await viewModel.load()
        }
    }

    private func summaryCards(_ summary: FleetSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)]) {
            SummaryCard(title: "Compliant", value: "\(summary.compliantCount)", color: .green)
            SummaryCard(title: "Noncompliant", value: "\(summary.noncompliantCount)", color: .red)
            SummaryCard(title: "Encryption Issues", value: "\(summary.encryptionIssues)", color: .orange)
            SummaryCard(title: "High Risk", value: "\(summary.highRiskCount)", color: .purple)
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity")
                .font(.headline)
            ForEach(viewModel.recentDevices) { device in
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.subheadline)
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
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
