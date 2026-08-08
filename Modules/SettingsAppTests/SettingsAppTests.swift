@testable import ApiImplementation

import ApiInterface
import Dependencies
import XCTest

@MainActor
final class SettingsAppTests: XCTestCase {
    func testSettingsList() async throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Correspondents"].exists)
        XCTAssertTrue(app.buttons["Document types"].exists)
        XCTAssertTrue(app.buttons["Licenses"].exists)
        XCTAssertTrue(app.buttons["Servers"].exists)
        XCTAssertTrue(app.buttons["Storage paths"].exists)
        XCTAssertTrue(app.buttons["Saved views"].exists)
        XCTAssertTrue(app.buttons["Tags"].exists)
    }

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
    }
}
