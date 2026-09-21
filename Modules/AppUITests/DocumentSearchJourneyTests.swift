import UITestSupport
import XCTest

@MainActor
final class DocumentSearchJourneyTests: UITestCase {

    // Reads the seeded corpus and modifies nothing. The seed's entities are unowned, so the Manual
    // tag is visible to the user this journey runs as — which is what makes the result assertable
    // without creating anything.
    func testSearchingRevealsATagAndFiltersByIt() async throws {
        launch()

        let documents = DocumentListScreen(app: app, timeout: timeout)
        XCTAssertTrue(documents.open(), "Could not open the Documents tab")

        XCTAssertTrue(documents.search(for: "man"), "Could not reach the search field")

        XCTAssertTrue(
            app.staticTexts["Tags"].waitForExistence(timeout: timeout),
            "Searching for man did not show a Tags section"
        )
        XCTAssertTrue(
            app.staticTexts["Manual"].waitForExistence(timeout: timeout),
            "Searching for man did not offer the Manual tag"
        )

        XCTAssertTrue(documents.tapSearchResult("Manual"), "Could not tap the Manual tag result")

        // The count is what proves the list actually narrowed — Puky alone is also a member of the
        // full 25-document corpus, so its presence survives even a tap that applied no filter at
        // all.
        XCTAssertTrue(
            app.staticTexts["6 of 6 loaded"].waitForExistence(timeout: timeout),
            "Filtering by the Manual tag did not narrow the list to its six documents"
        )
        XCTAssertTrue(
            app.staticTexts["Puky"].exists,
            "Filtering by the Manual tag did not leave Puky in the list"
        )
    }
}
