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

        // A document row rather than any cell: the search field is a row of this list and exists
        // before a single document has arrived.
        return app.documentRows.firstMatch.waitForExistence(timeout: timeout)
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

    // The list's first row is the search field itself — an ordinary textField, not a searchField:
    // nothing here is `.searchable`. Typing three characters is what swaps the document rows for
    // the result sections, so the caller waits on those rather than on this returning.
    @discardableResult
    public func search(for text: String) -> Bool {
        let field = searchField
        guard field.waitUntilHittable(timeout: timeout) else {
            return false
        }
        field.tap()
        guard app.keyboards.element.waitForExistence(timeout: timeout) else {
            return false
        }
        app.typeText(text)
        return true
    }

    // Read rather than tapped, so it deliberately does not wait on hittability: every assertion
    // using this is about what the field is left holding.
    public func searchFieldText() -> String? {
        let field = searchField
        guard field.waitForExistence(timeout: timeout) else {
            return nil
        }
        return field.value as? String
    }

    // The field's placeholder renders as its value when it is empty, which is what an emptied
    // field reports rather than "".
    public func isSearchFieldEmpty() -> Bool {
        searchFieldText().map { $0.isEmpty || $0 == "Search" } ?? false
    }

    @discardableResult
    public func cancelSearch() -> Bool {
        let cancel = app.buttons["Cancel"].firstMatch
        guard cancel.waitUntilHittable(timeout: timeout) else {
            return false
        }
        cancel.tap()
        return true
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
