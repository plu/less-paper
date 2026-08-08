@testable import ApiImplementation

import ApiInterface
import Dependencies
import XCTest

@MainActor
final class ServersAppTests: XCTestCase {
    func testCRUD() async throws {
        let url = URL.testValue()
        let hostAndPort = try url.hostAndPort.get()
        let app = XCUIApplication()
        app.launch()

        app.navigationBars.buttons["Add server"].tap()
        app.buttons["Scheme, https://"].tap()
        app.buttons["\(url.scheme ?? "http")://"].tap()
        app.textFields["Domain"].tap()
        app.typeText(hostAndPort)
        app.textFields["Username"].tap()
        app.typeText("admin")
        app.secureTextFields["Password"].tap()
        app.typeText("T0PS3CR3T!!123")
        app.textFields["Alias"].tap()
        app.typeText("CI")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        XCTAssertTrue(app.staticTexts["CI"].exists)
        XCTAssertTrue(app.staticTexts["admin @ \(url.absoluteString)"].exists)

        app.cells.firstMatch.swipeLeft()
        app.buttons["Edit server"].firstMatch.tap()
        app.textFields["Alias"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        XCTAssertTrue(app.staticTexts["CI Updated"].exists)

        app.cells.firstMatch.swipeLeft()
        app.buttons["Delete server"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"CI Updated\"?"].waitForExistence(timeout: timeout))
        app.buttons["Delete server"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["No servers found"].exists)
    }

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
    }

    private let server = Server.testValue()
    private let timeout = 5.0
}
