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

        // The whole point of the rebuild: the sheet goes away on a result tap and hands the
        // navigation bar back, rather than holding it hostage behind a Close button.
        XCTAssertTrue(
            app.buttons["Filter"].waitForExistence(timeout: timeout),
            "Tapping the \(name) result did not leave the Filter button reachable"
        )
        XCTAssertTrue(
            app.buttons["More actions"].exists,
            "Tapping the \(name) result did not leave the More actions button reachable"
        )
        XCTAssertFalse(
            app.navigationBars.buttons["Close"].exists,
            "Tapping the \(name) result left a Close button in the navigation bar"
        )

        // The query outlives the sheet: `search` is a permanent child of the list's state rather
        // than presentation state. The list's own copy of the field shows it without the sheet
        // being open at all, and reopening resumes the same search.
        XCTAssertEqual(
            documents.searchRowQuery(),
            name,
            "The list's search row did not show the query the sheet was closed on"
        )

        XCTAssertTrue(documents.openSearchSheet(), "Could not reopen the search sheet")
        XCTAssertEqual(
            documents.searchFieldText(),
            name,
            "Reopening the sheet did not restore the typed text in the search field"
        )

        // The sheet's own way out, which is neither a result tap nor the return key.
        XCTAssertTrue(documents.closeSearchSheet(), "Could not close the search sheet")
        XCTAssertTrue(
            app.buttons["Filter"].waitForExistence(timeout: timeout),
            "Closing the search sheet did not return to the document list"
        )
        XCTAssertEqual(
            documents.searchRowQuery(),
            name,
            "Closing the sheet discarded the query instead of keeping it"
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
