import Foundation

public protocol AIAssistantProviding {
    func summarizeCompliance(for device: DeviceDetailInfo) -> String
    func generateRunbook(for devices: [DeviceDetailInfo]) -> String
}

public struct LocalAssistant: AIAssistantProviding {
    public init() {}

    public func summarizeCompliance(for device: DeviceDetailInfo) -> String {
        var actions: [String] = []
        if !device.complianceSignals.fileVaultEnabled {
            actions.append("Enable FileVault")
        }
        if !device.complianceSignals.passcodeEnabled {
            actions.append("Require passcode")
        }
        if !device.complianceSignals.edrPresent {
            actions.append("Install EDR agent")
        }
        if device.complianceSignals.riskyAppsCount > 0 {
            actions.append("Review \(device.complianceSignals.riskyAppsCount) risky apps")
        }
        if actions.isEmpty {
            return "Device is compliant. No action needed."
        }
        return actions.joined(separator: "; ")
    }

    public func generateRunbook(for devices: [DeviceDetailInfo]) -> String {
        let nonCompliant = devices.filter { device in
            !device.complianceSignals.fileVaultEnabled || !device.complianceSignals.passcodeEnabled || !device.complianceSignals.edrPresent
        }
        let header = "Runbook for \(devices.count) devices"
        guard !nonCompliant.isEmpty else {
            return "\(header)\n\nAll selected devices are compliant."
        }
        let steps = nonCompliant.map { device in
            "- \(device.name) (\(device.platform.rawValue)) → \(summarizeCompliance(for: device))"
        }
        return ([header, "", "Next steps:"] + steps).joined(separator: "\n")
    }
}

public struct RemoteAssistant: AIAssistantProviding {
    public struct RedactedPayload {
        public let deviceId: String
        public let platform: String
        public let complianceSignals: ComplianceSignals
    }

    public init() {}

    public func summarizeCompliance(for device: DeviceDetailInfo) -> String {
        return "Remote assistant is disabled. Enable it in settings to use LLM summaries."
    }

    public func generateRunbook(for devices: [DeviceDetailInfo]) -> String {
        return "Remote assistant is disabled. Enable it in settings to use LLM runbooks."
    }

    public func redactedPayload(for device: DeviceDetailInfo) -> RedactedPayload {
        RedactedPayload(
            deviceId: device.id,
            platform: device.platform.rawValue,
            complianceSignals: device.complianceSignals
        )
    }
}
