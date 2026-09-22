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

    // The list's first row is a read-only copy of the search field, collapsed to a single button
    // so it never announces as editable. It opens a sheet holding the real field, which is an
    // ordinary textField, not a searchField: nothing here is `.searchable`.
    @discardableResult
    public func search(for text: String) -> Bool {
        guard openSearchSheet() else {
            return false
        }
        let field = searchField
        guard field.waitForExistence(timeout: timeout) else {
            return false
        }
        // The sheet focuses the field itself, but the keyboard is what `typeText` needs and it
        // arrives a frame or two later. Tapping is the fallback, not the happy path: a tap landing
        // mid-presentation can miss the field entirely.
        if !app.keyboards.element.waitForExistence(timeout: timeout) {
            guard field.waitUntilHittable(timeout: timeout) else {
                return false
            }
            field.tap()
            guard app.keyboards.element.waitForExistence(timeout: timeout) else {
                return false
            }
        }
        app.typeText(text)
        return true
    }

    @discardableResult
    public func openSearchSheet() -> Bool {
        let button = app.buttons["Search"].firstMatch
        guard button.waitUntilHittable(timeout: timeout) else {
            return false
        }
        button.tap()
        return true
    }

    // Read rather than tapped, so it deliberately does not wait on hittability: the assertion is
    // about what the field still holds when the sheet is reopened.
    public func searchFieldText() -> String? {
        let field = searchField
        guard field.waitForExistence(timeout: timeout) else {
            return nil
        }
        return field.value as? String
    }

    @discardableResult
    public func closeSearchSheet() -> Bool {
        let close = app.buttons["Close"].firstMatch
        guard close.waitUntilHittable(timeout: timeout) else {
            return false
        }
        close.tap()
        return true
    }

    // The list's copy carries the current query as its accessibility value, so this reads what
    // the list is showing without opening the sheet.
    public func searchRowQuery() -> String? {
        let button = app.buttons["Search"].firstMatch
        guard button.waitForExistence(timeout: timeout) else {
            return nil
        }
        return button.value as? String
    }

    private var searchField: XCUIElement {
        app.textFields["Search"].firstMatch
    }

    // The Tags and Document types sections can both offer a result with the same label (seed data
    // has "Manual" as both a tag and a document type), and section order in the results list puts
    // Tags first, so firstMatch resolves to the tag when both are present.
    @discardableResult
    public func tapSearchResult(_ label: String) -> Bool {
        let result = app.buttons.containing(.staticText, identifier: label).firstMatch
        guard result.waitUntilHittable(timeout: timeout) else {
            return false
        }
        result.tap()
        return true
    }
}
