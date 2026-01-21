import XCTest
@testable import DeviceOpsCore
import DeviceOpsAPI

final class DeviceOpsCoreTests: XCTestCase {
    func testPaginationAppendResetsOnFirstPage() {
        var state = PaginationState<Device>()
        let page1 = Page(page: 1, totalPages: 3, items: [
            Device(id: "1", name: "Alpha", platform: .macOS, osVersion: "14.2", compliance: .compliant, lastCheckIn: Date())
        ])
        state.appendPage(page1)
        XCTAssertEqual(state.items.count, 1)

        let page2 = Page(page: 2, totalPages: 3, items: [
            Device(id: "2", name: "Beta", platform: .iOS, osVersion: "17.1", compliance: .noncompliant, lastCheckIn: Date())
        ])
        state.appendPage(page2)
        XCTAssertEqual(state.items.count, 2)

        let page1Reload = Page(page: 1, totalPages: 3, items: [
            Device(id: "3", name: "Gamma", platform: .iPadOS, osVersion: "17.2", compliance: .unknown, lastCheckIn: Date())
        ])
        state.appendPage(page1Reload)
        XCTAssertEqual(state.items, page1Reload.items)
    }

    func testCommandStateMachineTransitions() {
        let machine = CommandJobStateMachine()
        XCTAssertEqual(machine.transition(current: .queued, event: .started), .inProgress)
        XCTAssertEqual(machine.transition(current: .inProgress, event: .succeeded), .succeeded)
        XCTAssertEqual(machine.transition(current: .queued, event: .failed(reason: "timeout")), .failed)
        XCTAssertEqual(machine.transition(current: .failed, event: .started), .failed)
    }

    func testAssetReconciliation() {
        let assets = [
            Asset(id: "1", assetTag: "A-1", serialNumber: "SERIAL-D1", assignedUser: "Avery", costCenter: "IT", lifecycleState: "in-use"),
            Asset(id: "2", assetTag: "A-2", serialNumber: "SERIAL-D2", assignedUser: "Blake", costCenter: "IT", lifecycleState: "in-use")
        ]
        let devices = [
            Device(id: "D1", name: "Alpha", platform: .macOS, osVersion: "14.2", compliance: .compliant, lastCheckIn: Date()),
            Device(id: "D3", name: "Beta", platform: .iOS, osVersion: "17.1", compliance: .noncompliant, lastCheckIn: Date())
        ]
        let result = AssetReconciler().reconcile(assets: assets, devices: devices)
        XCTAssertEqual(result.matched.count, 1)
        XCTAssertEqual(result.unmatchedAssets.count, 1)
        XCTAssertEqual(result.unmatchedDevices.count, 1)
    }

    func testAPIErrorMapping() {
        let service = DeviceOpsAPIService(config: DeviceOpsConfig(baseURL: URL(string: "http://localhost")!, token: nil))
        let error = service.performErrorMapping(APIError.httpError(401))
        XCTAssertEqual(error, DeviceOpsError.unauthorized)
    }
}
