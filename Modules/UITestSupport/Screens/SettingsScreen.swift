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

    // Which of the given sections the list does not hold, looked for all at once rather than one
    // after another.
    //
    // Asking about them one at a time is what broke: each lookup could only swipe *up*, so a
    // caller naming several sections in sequence silently required its names to be in the screen's
    // own top-to-bottom order. Moving PDF passwords out of Library and down into "This device"
    // left Saved views above the viewport by the time it was asked for, and reported a row as
    // missing that had been on screen the whole time. Held as a set here, so the order a caller
    // writes its names in means nothing.
    //
    // Every missing name is returned rather than the first: a reordering strands a run of them at
    // once, and one name per run is several runs to learn that.
    public func missingSections(_ names: [String]) -> [String] {
        var missing = Set(names)

        // One look before the first swipe and one after each of them. Bounded rather than `while`:
        // a section that never arrives should fail the caller's assertion, not scroll until the
        // test times out.
        for attempt in 0 ... 8 {
            if attempt > 0 {
                app.swipeUp()
            }
            missing = missing.filter { !app.staticTexts[$0].firstMatch.exists }
            if missing.isEmpty {
                return []
            }
        }

        return missing.sorted()
    }

    @discardableResult
    public func openSection(_ name: String) -> Bool {
        guard let row = scrollToSection(name) else {
            return false
        }
        row.tap()
        return true
    }

    // Scrolls, because `exists` alone is not enough: a SwiftUI `List` renders lazily, so a row
    // below the fold is not in the hierarchy at all and reads as absent. Every caller gets that
    // treatment now — the section headers pushed each Library row one place further down, which is
    // all it takes for the last of them to fall off a shorter screen.
    private func scrollToSection(_ name: String) -> XCUIElement? {
        let row = app.staticTexts[name].firstMatch
        if row.waitForExistence(timeout: 1.0) {
            return row
        }

        for _ in 0 ..< 8 {
            app.swipeUp()
            if row.exists {
                return row
            }
        }

        return nil
    }
}
