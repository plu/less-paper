import Foundation
import XCTest

@MainActor
public struct DocumentFormScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    // Via the detail screen's toolbar rather than the row's context menu. A context menu leaves an
    // AdditionalDimmingOverlay behind while it tears down, and CI captures showed one still in the
    // hierarchy under the presented sheet — taps on the sheet went nowhere. A plain row tap and a
    // toolbar button involve none of that machinery.
    @discardableResult
    public func openFromDocumentList() -> Bool {
        let tab = app.tabBars.buttons["Documents"]
        guard tab.waitUntilHittable(timeout: timeout) else {
            return false
        }
        tab.tap()

        let cell = app.cells.firstMatch
        guard cell.waitUntilHittable(timeout: timeout) else {
            return false
        }
        cell.tap()

        let edit = app.navigationBars.buttons["Edit"].firstMatch
        guard edit.waitUntilHittable(timeout: timeout) else {
            return false
        }
        edit.tap()

        return app.staticTexts["Edit document"].waitForExistence(timeout: timeout)
    }

    // "More options" is the sheet's section menu. "More actions" is the document list's toolbar
    // button, which sits behind the sheet in the same corner — matching that one taps through to
    // roughly the right place and passes by luck, until a different screen geometry moves it.
    @discardableResult
    public func openCustomFieldsSection() -> Bool {
        tapMenu(app.buttons["More options"].firstMatch, thenTap: "Custom fields")
    }

    @discardableResult
    public func attachCustomField(named name: String) -> Bool {
        tapMenu(app.buttons["Add field"].firstMatch, thenTap: name)
    }

    // A SwiftUI Menu drops a tap that lands while the sheet behind it is still settling, and a menu
    // that never opened leaves nothing to wait on — the whole journey then fails on a timing
    // artefact. Reopening is harmless, so the reveal is retried the way tapSwipeAction retries its
    // drag.
    private func tapMenu(
        _ trigger: XCUIElement,
        thenTap option: String,
        attempts: Int = 3
    ) -> Bool {
        guard trigger.waitUntilHittable(timeout: timeout) else {
            return false
        }

        let item = app.buttons[option].firstMatch
        for _ in 0 ..< attempts {
            trigger.tap()
            if item.waitUntilHittable(timeout: timeout) {
                item.tap()
                return true
            }
        }
        return false
    }
}
