import XCTest

public extension XCUIApplication {

    /**
     * Reveals a row's swipe actions and taps the action carrying the given accessibility label.
     *
     * Waits for the row to become interactive first, then retries the reveal, because a single
     * drag can be lost while a sheet is still animating away. Revealing is idempotent, so a
     * retry cannot fire an action twice.
     *
     * - Parameters:
     *   - label: The accessibility label of the swipe action button
     *   - cell: The row whose swipe actions should be revealed
     *   - timeout: How long to wait for the button after each reveal attempt
     *   - attempts: How many times to attempt the reveal before failing
     *   - file: The file the call originates from, used to report failures
     *   - line: The line the call originates from, used to report failures
     */
    func tapSwipeAction(
        _ label: String,
        in cell: XCUIElement,
        timeout: TimeInterval,
        attempts: Int = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard cell.waitUntilHittable(timeout: timeout) else {
            XCTFail("Row never became interactive, cannot reveal \"\(label)\"", file: file, line: line)
            return
        }

        let button = buttons[label].firstMatch
        for _ in 0 ..< attempts {
            cell.revealSwipeActions()
            if button.waitForExistence(timeout: timeout), button.isHittable {
                button.tap()
                return
            }
        }

        XCTFail("Swipe action \"\(label)\" never appeared after \(attempts) attempts", file: file, line: line)
    }
}
