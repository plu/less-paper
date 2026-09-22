import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class DocumentSearchJourneyTests: UITestCase {

    // The corpus is shared and unowned, so a journey that asserts on search results has to bring
    // its own tag and document rather than lean on whatever an instance happens to seed. Searching
    // for the tag's own (unique) name and narrowing to the one document that carries it proves both
    // that the tag surfaces as a search result and that tapping it actually filters.
    func testSearchingRevealsATagAndFiltersByIt() async throws {
        let name = "\(user.namespace)-tag"
        let tagId = try await Fixtures.createTag(named: name, token: user.token)
        self.tagId = tagId

        let title = "\(user.namespace)-doc"
        documentId = try await Fixtures.uploadDocument(titled: title, tags: [tagId], token: user.token)

        launch()

        let documents = DocumentListScreen(app: app, timeout: timeout)
        XCTAssertTrue(documents.open(), "Could not open the Documents tab")

        // A document result is the one tap that leaves the query alone, so the detail is pushed
        // over the results and going back lands on them again rather than on the whole library.
        XCTAssertTrue(documents.search(for: title), "Could not reach the search field")
        XCTAssertTrue(
            app.staticTexts["Documents"].waitForExistence(timeout: timeout),
            "Searching for \(title) did not show a Documents section"
        )
        XCTAssertTrue(documents.tapSearchResult(title), "Could not tap the \(title) document result")
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "Tapping the \(title) result did not push the document detail"
        )

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertEqual(
            documents.searchFieldText(),
            title,
            "Coming back from the document discarded the query instead of keeping it"
        )
        XCTAssertTrue(
            app.staticTexts["Documents"].waitForExistence(timeout: timeout),
            "Coming back from the document did not return to the search results"
        )

        // Cancel is the way out that the field's own `X` is not: one tap back to the documents.
        XCTAssertTrue(documents.cancelSearch(), "Could not cancel the search")
        XCTAssertTrue(
            app.buttons["Filter"].waitForExistence(timeout: timeout),
            "Cancelling the search did not return to the document list"
        )
        XCTAssertTrue(
            documents.isSearchFieldEmpty(),
            "Cancelling the search left the query in the field"
        )

        XCTAssertTrue(documents.search(for: name), "Could not reach the search field")

        XCTAssertTrue(
            app.staticTexts["Tags"].waitForExistence(timeout: timeout),
            "Searching for \(name) did not show a Tags section"
        )
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "Searching for \(name) did not offer the \(name) tag"
        )

        XCTAssertTrue(documents.tapSearchResult(name), "Could not tap the \(name) tag result")

        // The count is what proves the list actually narrowed, not merely that the document still
        // exists: the tag and document are both unique to this run, so exactly one document can
        // carry it, which makes "1 of 1" the deterministic result regardless of corpus size.
        XCTAssertTrue(
            app.staticTexts["1 of 1 loaded"].waitForExistence(timeout: timeout),
            "Filtering by \(name) did not narrow the list to its one document"
        )
        XCTAssertTrue(
            app.staticTexts[title].exists,
            "Filtering by \(name) did not leave \(title) in the list"
        )

        // Applying a filter ends the search: it is visible in the list from then on, so the field
        // that produced it has nothing left to say.
        XCTAssertTrue(
            documents.isSearchFieldEmpty(),
            "Tapping the \(name) result left the query in the field"
        )

        // The whole point of the rebuild: nothing ever takes the navigation bar, so Filter and
        // More actions are reachable throughout.
        XCTAssertTrue(
            app.buttons["Filter"].waitForExistence(timeout: timeout),
            "Tapping the \(name) result did not leave the Filter button reachable"
        )
        XCTAssertTrue(
            app.buttons["More actions"].exists,
            "Tapping the \(name) result did not leave the More actions button reachable"
        )
    }

    override func tearDown() async throws {
        if let documentId {
            try? await Fixtures.deleteDocument(id: documentId, token: user.token)
        }
        documentId = nil

        if let tagId {
            try? await Fixtures.deleteTag(id: tagId, token: user.token)
        }
        tagId = nil

        try await super.tearDown()
    }

    private var documentId: Document.Id?

    private var tagId: Tag.Id?
}
