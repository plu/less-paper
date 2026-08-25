import Foundation
import XCTest

@MainActor
public struct TagListScreen {

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
    public func createTag(named name: String) -> Bool {
        let addButton = app.buttons["Add tag"].firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        guard type(name, into: app.textFields["Name"]) else {
            return false
        }

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func editTag(named name: String, appending suffix: String) -> Bool {
        guard let cell = cell(containing: name) else {
            return false
        }
        app.tapSwipeAction("Edit tag", in: cell, timeout: timeout)

        guard type(suffix, into: app.textFields["Name"]) else {
            return false
        }

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func deleteTag(named name: String) -> Bool {
        guard let cell = cell(containing: name) else {
            return false
        }
        app.tapSwipeAction("Delete tag", in: cell, timeout: timeout)

        let confirm = app.buttons["Confirm"].firstMatch
        guard confirm.waitForExistence(timeout: timeout) else {
            return false
        }
        confirm.tap()
        return app.staticTexts[name].waitForNonExistence(timeout: timeout)
    }

    private func cell(containing name: String) -> XCUIElement? {
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        guard cell.waitForExistence(timeout: timeout) else {
            return nil
        }
        return cell
    }

    private func type(
        _ text: String,
        into element: XCUIElement
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            return false
        }
        element.tap()
        app.typeText(text)
        return true
    }
}
