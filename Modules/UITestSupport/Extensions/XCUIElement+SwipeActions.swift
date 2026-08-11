import XCTest

public extension XCUIElement {

    /// Reveals the trailing swipe actions of a list row.
    ///
    /// Deliberately not `swipeLeft()`: that synthesizes a fast, full-width flick whose timing
    /// varies with host load, so it can be interpreted as a tap on the row itself, or cross
    /// SwiftUI's full-swipe threshold — which performs the first trailing action instead of
    /// revealing it. A slow drag across 45% of the row width can do neither.
    func revealSwipeActions() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
    }

    /**
     * Waits for the element to exist and become interactive.
     *
     * Existence alone is not enough after a sheet is dismissed: the row is back in the
     * accessibility tree while the presentation is still animating away, but gestures sent to it
     * during that window are delivered against a stale frame.
     *
     * - Parameter timeout: How long to wait for each of the two conditions
     * - Returns: `true` if the element exists and is hittable within the timeout
     */
    @discardableResult
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        waitForExistence(timeout: timeout)
            && wait(for: \.isHittable, toEqual: true, timeout: timeout)
    }
}
