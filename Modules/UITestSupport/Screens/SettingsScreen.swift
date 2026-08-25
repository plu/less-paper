import Foundation
import XCTest

@MainActor
public struct SettingsScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    @discardableResult
    public func open() -> Bool {
        let tab = app.tabBars.buttons["Settings"]
        guard tab.waitForExistence(timeout: timeout) else {
            return false
        }
        tab.tap()
        return app.staticTexts["Servers"].waitForExistence(timeout: timeout)
    }

    @discardableResult
    public func openSection(_ name: String) -> Bool {
        let row = app.staticTexts[name].firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            return false
        }
        row.tap()
        return true
    }
}
