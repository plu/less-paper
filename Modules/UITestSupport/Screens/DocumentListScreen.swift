import Foundation
import XCTest

@MainActor
public struct DocumentListScreen {

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
        let tab = app.tabBars.buttons["Documents"]
        guard tab.waitUntilHittable(timeout: timeout) else {
            return false
        }
        tab.tap()
        return app.cells.firstMatch.waitForExistence(timeout: timeout)
    }

    @discardableResult
    public func open(documentTitled title: String) -> Bool {
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        guard cell.waitUntilHittable(timeout: timeout) else {
            return false
        }
        cell.tap()
        return true
    }

    // The caller waits on the filtered rows rather than on this returning. The harness this
    // replaces slept 700ms for the search debounce; the rows themselves are the same wait without
    // the guess.
    @discardableResult
    public func filter(byTitle text: String) -> Bool {
        let filter = app.buttons["Filter"].firstMatch
        guard filter.waitUntilHittable(timeout: timeout) else {
            return false
        }
        filter.tap()

        let field = app.textFields["Title & content"].firstMatch
        guard field.waitForExistence(timeout: timeout) else {
            return false
        }
        field.tap()
        app.typeText(text)

        let close = app.buttons["Close"].firstMatch
        guard close.waitUntilHittable(timeout: timeout) else {
            return false
        }
        close.tap()
        return true
    }
}
