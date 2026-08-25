import Foundation
import XCTest

@MainActor
public struct EntityListScreen {

    public struct Entity: Sendable {

        public static let correspondent = Self(
            add: "Add correspondent",
            delete: "Delete correspondent",
            edit: "Edit correspondent"
        )

        public static let documentType = Self(
            add: "Add document type",
            delete: "Delete document type",
            edit: "Edit document type"
        )

        public static let savedView = Self(
            add: "Add saved view",
            delete: "Delete saved view",
            edit: "Edit saved view"
        )

        public static let storagePath = Self(
            add: "Add storage path",
            delete: "Delete storage path",
            edit: "Edit storage path"
        )

        public static let tag = Self(
            add: "Add tag",
            delete: "Delete tag",
            edit: "Edit tag"
        )

        let add: String

        let delete: String

        let edit: String
    }

    public let app: XCUIApplication

    public let entity: Entity

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        entity: Entity,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.entity = entity
        self.timeout = timeout
    }

    @discardableResult
    public func create(
        named name: String,
        extras: (Self) -> Void = { _ in }
    ) -> Bool {
        // The list renders a ProgressView until updateCache resolves, so the toolbar button does
        // not exist at launch and tapping straight away races that fetch.
        let addButton = app.buttons[entity.add].firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        guard type(name, into: "Name") else {
            return false
        }
        extras(self)

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func delete(named name: String) -> Bool {
        guard let row = row(named: name) else {
            return false
        }
        app.tapSwipeAction(entity.delete, in: row, timeout: timeout)

        let confirm = app.buttons["Confirm"].firstMatch
        guard confirm.waitForExistence(timeout: timeout) else {
            return false
        }
        confirm.tap()
        return app.staticTexts[name].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func edit(
        named name: String,
        appending suffix: String
    ) -> Bool {
        guard let row = row(named: name) else {
            return false
        }
        app.tapSwipeAction(entity.edit, in: row, timeout: timeout)

        guard type(suffix, into: "Name") else {
            return false
        }

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    public func row(named name: String) -> XCUIElement? {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            return nil
        }
        return row
    }

    @discardableResult
    public func type(
        _ text: String,
        into field: String
    ) -> Bool {
        let element = app.textFields[field]
        guard element.waitForExistence(timeout: timeout) else {
            return false
        }
        element.tap()
        app.typeText(text)
        return true
    }
}
