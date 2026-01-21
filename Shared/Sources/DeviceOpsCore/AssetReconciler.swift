import Foundation

public struct AssetReconciliationResult: Equatable {
    public let matched: [Asset]
    public let unmatchedAssets: [Asset]
    public let unmatchedDevices: [Device]
}

public struct AssetReconciler {
    public init() {}

    public func reconcile(assets: [Asset], devices: [Device]) -> AssetReconciliationResult {
        let deviceSerials = Set(devices.map { "SERIAL-\($0.id)" })
        let matched = assets.filter { deviceSerials.contains($0.serialNumber) }
        let unmatchedAssets = assets.filter { !deviceSerials.contains($0.serialNumber) }
        let assetSerials = Set(assets.map { $0.serialNumber })
        let unmatchedDevices = devices.filter { !assetSerials.contains("SERIAL-\($0.id)") }
        return AssetReconciliationResult(
            matched: matched,
            unmatchedAssets: unmatchedAssets,
            unmatchedDevices: unmatchedDevices
        )
    }
}
