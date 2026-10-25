import XCTest

final class HeatingNavigationTests: XCTestCase {
    @MainActor func testHeatingPageIsAvailableWithoutController() {
        let app = XCUIApplication()
        app.launch()
        let heating = app.buttons["Heating"]
        XCTAssertTrue(heating.waitForExistence(timeout: 15))
        heating.tap()
        XCTAssertTrue(app.staticTexts["Agile heating"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Always-running controller"].exists)
        XCTAssertTrue(app.staticTexts["Heating policy: unavailable"].exists)
        XCTAssertTrue(app.staticTexts["Heating state: unavailable"].exists)
        XCTAssertTrue(app.staticTexts["Automatic control disabled"].exists)
        XCTAssertTrue(app.buttons["Test connection / reload controller policy"].exists)
        XCTAssertTrue(app.switches["heating-automation-switch"].exists)
        XCTAssertFalse(app.switches["heating-automation-switch"].isEnabled)
        XCTAssertFalse(app.textFields["heating-controller-address"].exists)
        XCTAssertFalse(app.secureTextFields["heating-controller-key"].exists)
        XCTAssertFalse(app.buttons["Save policy to controller"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Heating controller connection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.textFields["heating-controller-address"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["heating-controller-key"].exists)
        XCTAssertTrue(app.buttons["Save connection"].exists)
    }
}
