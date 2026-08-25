import XCTest

public extension XCUIElement {

    // Tapping the centre of a field that already holds text drops the caret between whichever two
    // characters sit under the midpoint, so appended text lands inside the value: editing
    // uit-6dda3227-document-types produced uit-6dda3227-document Updated-types. The trailing edge is
    // past the last glyph, which is where an append has to start. An empty field focuses at
    // position 0 either way, so this is safe for both.
    func tapAfterExistingText() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    }
}
