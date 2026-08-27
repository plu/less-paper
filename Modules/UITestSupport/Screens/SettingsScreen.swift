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

    /// Whether a section is on the list, scrolling to find it.
    ///
    /// `exists` alone is not enough: a SwiftUI `List` renders lazily, so a row below the fold is not
    /// in the hierarchy at all. Asserting on `exists` silently depended on every section fitting one
    /// screen, and adding the tenth broke a test that had nothing to do with it.
    @discardableResult
    public func hasSection(_ name: String) -> Bool {
        let row = app.staticTexts[name].firstMatch
        if row.waitForExistence(timeout: 1.0) {
            return true
        }

        // Bounded rather than `while`: a section that never arrives should fail the assertion, not
        // scroll until the test times out.
        for _ in 0 ..< 6 {
            app.swipeUp()
            if row.exists {
                return true
            }
        }

        return false
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
