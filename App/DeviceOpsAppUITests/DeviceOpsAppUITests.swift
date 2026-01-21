import XCTest

final class DeviceOpsAppUITests: XCTestCase {
    func testOpenDeviceDetail() {
        let app = XCUIApplication()
        app.launch()

        let devicesTab = app.tabBars.buttons["Devices"]
        XCTAssertTrue(devicesTab.waitForExistence(timeout: 5))
        devicesTab.tap()

        let firstCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()

        let identityTitle = app.staticTexts["Identity"]
        XCTAssertTrue(identityTitle.waitForExistence(timeout: 5))
    }

    func testTriggerCommandAndSeeJobStatus() {
        let app = XCUIApplication()
        app.launch()

        let devicesTab = app.tabBars.buttons["Devices"]
        XCTAssertTrue(devicesTab.waitForExistence(timeout: 5))
        devicesTab.tap()

        let firstCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()

        let actionButton = app.buttons["action-query-device"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 5))
        actionButton.tap()

        let jobStatus = app.staticTexts["job-status"]
        XCTAssertTrue(jobStatus.waitForExistence(timeout: 5))
    }
}
