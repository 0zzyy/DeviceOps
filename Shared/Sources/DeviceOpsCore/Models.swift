import Foundation

public enum Platform: String, CaseIterable, Codable, Identifiable {
    case macOS
    case iOS
    case iPadOS
    case tvOS
    case visionOS

    public var id: String { rawValue }
}

public enum ComplianceStatus: String, CaseIterable, Codable, Identifiable {
    case compliant
    case noncompliant
    case unknown

    public var id: String { rawValue }
}

public struct FleetSummary: Equatable {
    public let platformCounts: [Platform: Int]
    public let compliantCount: Int
    public let noncompliantCount: Int
    public let encryptionIssues: Int
    public let highRiskCount: Int

    public init(platformCounts: [Platform: Int], compliantCount: Int, noncompliantCount: Int, encryptionIssues: Int, highRiskCount: Int) {
        self.platformCounts = platformCounts
        self.compliantCount = compliantCount
        self.noncompliantCount = noncompliantCount
        self.encryptionIssues = encryptionIssues
        self.highRiskCount = highRiskCount
    }
}

public struct Device: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let platform: Platform
    public let osVersion: String
    public let compliance: ComplianceStatus
    public let lastCheckIn: Date

    public init(id: String, name: String, platform: Platform, osVersion: String, compliance: ComplianceStatus, lastCheckIn: Date) {
        self.id = id
        self.name = name
        self.platform = platform
        self.osVersion = osVersion
        self.compliance = compliance
        self.lastCheckIn = lastCheckIn
    }
}

public struct DeviceDetailInfo: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let platform: Platform
    public let osVersion: String
    public let serialNumber: String
    public let lastCheckIn: Date
    public let complianceSignals: ComplianceSignals
    public let installedApps: [InstalledApp]

    public init(
        id: String,
        name: String,
        platform: Platform,
        osVersion: String,
        serialNumber: String,
        lastCheckIn: Date,
        complianceSignals: ComplianceSignals,
        installedApps: [InstalledApp]
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.osVersion = osVersion
        self.serialNumber = serialNumber
        self.lastCheckIn = lastCheckIn
        self.complianceSignals = complianceSignals
        self.installedApps = installedApps
    }
}

public struct ComplianceSignals: Equatable, Codable {
    public let fileVaultEnabled: Bool
    public let passcodeEnabled: Bool
    public let edrPresent: Bool
    public let riskyAppsCount: Int

    public init(fileVaultEnabled: Bool, passcodeEnabled: Bool, edrPresent: Bool, riskyAppsCount: Int) {
        self.fileVaultEnabled = fileVaultEnabled
        self.passcodeEnabled = passcodeEnabled
        self.edrPresent = edrPresent
        self.riskyAppsCount = riskyAppsCount
    }
}

public struct InstalledApp: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let version: String

    public init(id: String, name: String, version: String) {
        self.id = id
        self.name = name
        self.version = version
    }
}

public struct Asset: Identifiable, Equatable, Codable {
    public let id: String
    public let assetTag: String
    public let serialNumber: String
    public let assignedUser: String
    public let costCenter: String
    public let lifecycleState: String

    public init(id: String, assetTag: String, serialNumber: String, assignedUser: String, costCenter: String, lifecycleState: String) {
        self.id = id
        self.assetTag = assetTag
        self.serialNumber = serialNumber
        self.assignedUser = assignedUser
        self.costCenter = costCenter
        self.lifecycleState = lifecycleState
    }
}

public struct Software: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let version: String
    public let platform: Platform
    public let required: Bool

    public init(id: String, name: String, version: String, platform: Platform, required: Bool) {
        self.id = id
        self.name = name
        self.version = version
        self.platform = platform
        self.required = required
    }
}

public struct Page<T: Equatable & Codable>: Equatable, Codable {
    public let page: Int
    public let totalPages: Int
    public let items: [T]

    public init(page: Int, totalPages: Int, items: [T]) {
        self.page = page
        self.totalPages = totalPages
        self.items = items
    }
}

public enum CommandStatus: String, CaseIterable, Codable {
    case queued
    case inProgress = "in_progress"
    case succeeded
    case failed
}

public struct CommandJobInfo: Identifiable, Equatable, Codable {
    public let id: String
    public let status: CommandStatus
    public let commandType: String
    public let createdAt: Date
    public let completedAt: Date?
    public let failureReason: String?

    public init(id: String, status: CommandStatus, commandType: String, createdAt: Date, completedAt: Date?, failureReason: String?) {
        self.id = id
        self.status = status
        self.commandType = commandType
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.failureReason = failureReason
    }
}
