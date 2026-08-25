import Foundation
import XCTest

// The custom field form is the only one in the app with a nested collection, so it gets a driver of
// its own rather than riding EntityListScreen's extras closure alone.
@MainActor
public struct CustomFieldFormScreen {

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
    public func addOption(labelled label: String) -> Bool {
        let addOption = app.buttons["Add option"].firstMatch
        guard addOption.waitForExistence(timeout: timeout) else {
            return false
        }
        addOption.tap()

        // Deliberately no tap on the new row: it takes focus when it appears, so typing straight
        // away has to land in it. A tap here would hide a regression in that focus hand-off.
        guard app.textFields["Option"].firstMatch.waitForExistence(timeout: timeout) else {
            return false
        }
        app.typeText(label)
        return true
    }

    // A SwiftUI menu Picker is exposed as a button labelled with its *current* value, not with the
    // field title — "Data type" is only the Field's caption, and matches no button.
    @discardableResult
    public func chooseDataType(
        _ dataType: String,
        showing current: String = "Text"
    ) -> Bool {
        let picker = app.buttons[current].firstMatch
        guard picker.waitForExistence(timeout: timeout) else {
            return false
        }
        picker.tap()

        let choice = app.buttons[dataType].firstMatch
        guard choice.waitForExistence(timeout: timeout) else {
            return false
        }
        choice.tap()
        return true
    }

    public func firstOptionLabel() -> String? {
        let option = app.textFields["Option"].firstMatch
        guard option.waitForExistence(timeout: timeout) else {
            return nil
        }
        return option.value as? String
    }
}
