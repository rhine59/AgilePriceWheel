import XCTest

final class HeatingNavigationTests: XCTestCase {
    @MainActor func testHeatingPageIsAvailableWithoutController() {
        let app = XCUIApplication()
        app.launch()
        let heating = app.buttons["Heating"]
        XCTAssertTrue(heating.waitForExistence(timeout: 15))
        heating.tap()
        XCTAssertTrue(app.staticTexts["Always-running controller"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Live heating disabled"].exists)
        XCTAssertTrue(app.buttons["Connect / reload controller policy"].exists)
        XCTAssertTrue(app.textFields["heating-controller-address"].exists)
        XCTAssertTrue(app.secureTextFields["heating-controller-key"].exists)
        XCTAssertFalse(app.buttons["Save policy to controller"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Heating controller connection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
