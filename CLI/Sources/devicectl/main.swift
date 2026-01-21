import Foundation
import ArgumentParser
import DeviceOpsCore
import DeviceOpsAPI

@main
struct DeviceCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devicectl",
        abstract: "DeviceOps CLI for fleet automation",
        subcommands: [Devices.self, Commands.self, ReconcileAssets.self, ReportCompliance.self]
    )
}

struct Devices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(subcommands: [List.self, Info.self])

    struct List: AsyncParsableCommand {
        @Option(name: .shortAndLong, help: "Search query") var filter: String?
        @Option(help: "Page number") var page: Int = 1

        func run() async throws {
            let service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
            let result = try await service.fetchDevices(page: page, query: filter, platform: nil, compliance: nil)
            print("Page \(result.page)/\(result.totalPages)")
            for device in result.items {
                print("\(device.id) | \(device.name) | \(device.platform.rawValue) | \(device.compliance.rawValue)")
            }
        }
    }

    struct Info: AsyncParsableCommand {
        @Argument(help: "Device ID") var deviceId: String

        func run() async throws {
            let service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
            let detail = try await service.fetchDevice(id: deviceId)
            print("\(detail.name) (\(detail.platform.rawValue))")
            print("Serial: \(detail.serialNumber)")
            print("OS: \(detail.osVersion)")
            print("Last Check-in: \(detail.lastCheckIn)")
        }
    }
}

struct Commands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(subcommands: [Send.self])

    struct Send: AsyncParsableCommand {
        @Argument(help: "Device ID") var deviceId: String
        @Argument(help: "Command type") var commandType: String
        @Option(help: "Optional app ID for install") var appId: String?

        func run() async throws {
            let service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
            let payload = appId.map { ["appId": $0] }
            let job = try await service.sendCommand(deviceId: deviceId, command: CommandType(rawValue: commandType) ?? .queryDeviceInformation, payload: payload)
            print("Job \(job.id) status \(job.status.rawValue)")
        }
    }
}

struct ReconcileAssets: AsyncParsableCommand {
    @Option(help: "Export path") var export: String

    func run() async throws {
        let service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
        let devices = try await fetchAllDevices(using: service)
        let assets = try await fetchAllAssets(using: service)
        let result = AssetReconciler().reconcile(assets: assets, devices: devices)
        var csv = "status,assetTag,serialNumber,deviceId\n"
        for asset in result.unmatchedAssets {
            csv += "unmatched_asset,\(asset.assetTag),\(asset.serialNumber),\n"
        }
        for device in result.unmatchedDevices {
            csv += "unmatched_device,,\(device.id),\(device.id)\n"
        }
        try csv.write(to: URL(fileURLWithPath: export), atomically: true, encoding: .utf8)
        print("Exported reconciliation to \(export)")
    }
}

struct ReportCompliance: AsyncParsableCommand {
    @Option(help: "Export path") var export: String

    func run() async throws {
        let service = DeviceOpsAPIService(config: DeviceOpsConfig.load())
        let devices = try await fetchAllDevices(using: service)
        let compliant = devices.filter { $0.compliance == .compliant }.count
        let report = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "total": devices.count,
            "compliant": compliant
        ] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted])
        try data.write(to: URL(fileURLWithPath: export))
        print("Exported compliance report to \(export)")
    }
}

private func fetchAllDevices(using service: DeviceOpsServicing) async throws -> [Device] {
    var page = 1
    var collected: [Device] = []
    while true {
        let response = try await service.fetchDevices(page: page, query: nil, platform: nil, compliance: nil)
        collected.append(contentsOf: response.items)
        if response.page >= response.totalPages { break }
        page += 1
    }
    return collected
}

private func fetchAllAssets(using service: DeviceOpsServicing) async throws -> [Asset] {
    var page = 1
    var collected: [Asset] = []
    while true {
        let response = try await service.fetchAssets(page: page, query: nil)
        collected.append(contentsOf: response.items)
        if response.page >= response.totalPages { break }
        page += 1
    }
    return collected
}
