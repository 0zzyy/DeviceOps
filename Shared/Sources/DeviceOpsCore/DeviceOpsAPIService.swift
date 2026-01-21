import Foundation
import DeviceOpsAPI
#if canImport(os)
import os
#endif

public protocol DeviceOpsServicing {
    func fetchDevices(page: Int, query: String?, platform: Platform?, compliance: ComplianceStatus?) async throws -> Page<Device>
    func fetchDevice(id: String) async throws -> DeviceDetailInfo
    func sendCommand(deviceId: String, command: CommandType, payload: [String: String]?) async throws -> CommandJobInfo
    func commandStatus(jobId: String) async throws -> CommandJobInfo
    func fetchAssets(page: Int, query: String?) async throws -> Page<Asset>
    func fetchSoftware(page: Int, platform: Platform?) async throws -> Page<Software>
    func requestInstall(softwareId: String) async throws -> CommandJobInfo
}

public struct DeviceOpsAPIService: DeviceOpsServicing {
    private let client: DeviceOpsClient
    private let logger = DeviceOpsLogger()

    public init(config: DeviceOpsConfig) {
        self.client = DeviceOpsClient(baseURL: config.baseURL, token: config.token)
    }

    public func fetchDevices(page: Int, query: String?, platform: Platform?, compliance: ComplianceStatus?) async throws -> Page<Device> {
        return try await withRetry {
            let response = try await client.listDevices(
                page: page,
                query: query,
                platform: platform?.rawValue,
                compliance: compliance?.rawValue
            )
            return Page(
                page: response.page,
                totalPages: response.totalPages,
                items: response.items.map { mapDevice($0) }
            )
        }
    }

    public func fetchDevice(id: String) async throws -> DeviceDetailInfo {
        return try await withRetry {
            let detail = try await client.getDevice(id: id)
            return DeviceDetailInfo(
                id: detail.id,
                name: detail.name,
                platform: Platform(rawValue: detail.platform) ?? .macOS,
                osVersion: detail.osVersion,
                serialNumber: detail.serialNumber,
                lastCheckIn: detail.lastCheckIn,
                complianceSignals: ComplianceSignals(
                    fileVaultEnabled: detail.complianceSignals.fileVaultEnabled,
                    passcodeEnabled: detail.complianceSignals.passcodeEnabled,
                    edrPresent: detail.complianceSignals.edrPresent,
                    riskyAppsCount: detail.complianceSignals.riskyAppsCount
                ),
                installedApps: detail.installedApps.map { InstalledApp(id: $0.id, name: $0.name, version: $0.version) }
            )
        }
    }

    public func sendCommand(deviceId: String, command: CommandType, payload: [String: String]?) async throws -> CommandJobInfo {
        return try await withRetry {
            let job = try await client.sendCommand(
                deviceId: deviceId,
                requestBody: CommandRequest(commandType: command.rawValue, payload: payload)
            )
            logger.info("Command job created: \(job.id) status=\(job.status)")
            return mapJob(job)
        }
    }

    public func commandStatus(jobId: String) async throws -> CommandJobInfo {
        return try await withRetry {
            let job = try await client.getCommand(jobId: jobId)
            logger.info("Command job status: \(job.id) status=\(job.status)")
            return mapJob(job)
        }
    }

    public func fetchAssets(page: Int, query: String?) async throws -> Page<Asset> {
        return try await withRetry {
            let response = try await client.listAssets(page: page, query: query)
            return Page(
                page: response.page,
                totalPages: response.totalPages,
                items: response.items.map { Asset(
                    id: $0.id,
                    assetTag: $0.assetTag,
                    serialNumber: $0.serialNumber,
                    assignedUser: $0.assignedUser,
                    costCenter: $0.costCenter,
                    lifecycleState: $0.lifecycleState
                ) }
            )
        }
    }

    public func fetchSoftware(page: Int, platform: Platform?) async throws -> Page<Software> {
        return try await withRetry {
            let response = try await client.listSoftware(page: page, platform: platform?.rawValue)
            return Page(
                page: response.page,
                totalPages: response.totalPages,
                items: response.items.map { Software(
                    id: $0.id,
                    name: $0.name,
                    version: $0.version,
                    platform: Platform(rawValue: $0.platform) ?? .macOS,
                    required: $0.required
                ) }
            )
        }
    }

    public func requestInstall(softwareId: String) async throws -> CommandJobInfo {
        return try await withRetry {
            let job = try await client.requestInstall(softwareId: softwareId)
            logger.info("Install job created: \(job.id)")
            return mapJob(job)
        }
    }

    private func mapDevice(_ summary: DeviceSummary) -> Device {
        Device(
            id: summary.id,
            name: summary.name,
            platform: Platform(rawValue: summary.platform) ?? .macOS,
            osVersion: summary.osVersion,
            compliance: ComplianceStatus(rawValue: summary.compliance) ?? .unknown,
            lastCheckIn: summary.lastCheckIn
        )
    }

    private func mapJob(_ job: CommandJob) -> CommandJobInfo {
        CommandJobInfo(
            id: job.id,
            status: CommandStatus(rawValue: job.status) ?? .queued,
            commandType: job.commandType,
            createdAt: job.createdAt,
            completedAt: job.completedAt,
            failureReason: job.failureReason
        )
    }

    private func withRetry<T>(operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        var delay: UInt64 = 200_000_000
        while true {
            do {
                if Task.isCancelled { throw CancellationError() }
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as APIError {
                let mapped = mapError(error)
                if attempt < 3, mapped == .serverUnavailable || mapped == .networkUnavailable || mapped == .rateLimited {
                    attempt += 1
                    if Task.isCancelled { throw CancellationError() }
                    try await Task.sleep(nanoseconds: delay)
                    delay *= 2
                    continue
                }
                logger.error("API error: \(mapped.localizedDescription)")
                throw mapped
            } catch {
                logger.error("Unexpected error: \(error.localizedDescription)")
                throw DeviceOpsError.unknown(error.localizedDescription)
            }
        }
    }

    private func mapError(_ error: APIError) -> DeviceOpsError {
        switch error {
        case .httpError(let status):
            switch status {
            case 401: return .unauthorized
            case 404: return .notFound
            case 429: return .rateLimited
            case 500...599: return .serverUnavailable
            default: return .unexpectedResponse
            }
        case .decodingFailed:
            return .decodingFailed
        case .invalidResponse:
            return .unexpectedResponse
        case .transport:
            return .networkUnavailable
        }
    }
}

private struct DeviceOpsLogger {
#if canImport(os)
    private let logger = Logger(subsystem: "com.deviceops", category: "api")

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
#else
    func info(_ message: String) {}
    func error(_ message: String) {}
#endif
}

// MARK: - Test hooks

extension DeviceOpsAPIService {
    func performErrorMapping(_ error: APIError) -> DeviceOpsError {
        mapError(error)
    }
}
