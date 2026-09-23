import XCTest

// Matches DocumentRowView.accessibilityIdentifier. A test target cannot import DocumentsFeature, so
// the two are kept in step by name, the way SnapshotEnvironment.key is.
public enum DocumentRowElement {
    public static let identifier = "DocumentRow"
}

public extension XCUIApplication {

    // The documents list's first cell is the search field, not a document, and the tip invitation
    // can take a row above the documents as well — so `cells.firstMatch` opens whatever happens to
    // be at the top, which is what broke the screenshot and form journeys. Anything walking that
    // list asks for a document row by name instead, and a row added above them later fails nothing.
    //
    // `containing` rather than `matching`: SwiftUI puts a row's accessibility identifier on the
    // leaves it wraps — the thumbnail, the title, each chip — and leaves the cell itself
    // unidentified, so the cell is only reachable through the descendants that carry it.
    var documentRows: XCUIElementQuery {
        cells.containing(.any, identifier: DocumentRowElement.identifier)
    }
}
