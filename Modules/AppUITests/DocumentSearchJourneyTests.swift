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
        //
        // It also proves the tag filter survived the tap. Resigning the search field's focus makes
        // SwiftUI fire `onSubmit(of: .search)`, and an unsuppressed phantom submit would commit a
        // full text search for the tag's name over the top of the filter just applied. That search
        // matches nothing — the name is not in the document's content — so the collision shows up
        // here as an empty list rather than as "1 of 1".
        XCTAssertTrue(
            app.staticTexts["1 of 1 loaded"].waitForExistence(timeout: timeout),
            "Filtering by \(name) did not narrow the list to its one document"
        )
        XCTAssertTrue(
            app.staticTexts[title].exists,
            "Filtering by \(name) did not leave \(title) in the list"
        )

        // The whole point of resigning focus rather than calling `dismissSearch`: the overlay goes
        // away but the query stays, so tapping the field again resumes the same search. This is
        // asserted here because it is SwiftUI focus behaviour that no TestStore or snapshot reaches.
        XCTAssertEqual(
            documents.searchFieldText(),
            name,
            "Tapping the \(name) result did not leave the typed text in the search field"
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
