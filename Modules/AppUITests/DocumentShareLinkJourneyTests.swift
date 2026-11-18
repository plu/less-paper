import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class DocumentShareLinkJourneyTests: UITestCase {

    // Creating a link, seeing it listed and deleting it again. The document is the test user's own,
    // uploaded with its token, so the share link it carries is owned by the user too.
    func testCreatingAndDeletingAShareLink() async throws {
        let title = "\(user.namespace)-doc"
        documentId = try await Fixtures.uploadDocument(titled: title, token: user.token)

        launch()

        let documents = DocumentListScreen(app: app, timeout: timeout)
        XCTAssertTrue(documents.open(), "Could not open the Documents tab")

        let row = app.cells.containing(.staticText, identifier: title).firstMatch
        XCTAssertTrue(row.waitUntilHittable(timeout: timeout), "The uploaded document never appeared")
        row.press(forDuration: 1)

        let share = app.buttons["Share"].firstMatch
        XCTAssertTrue(share.waitUntilHittable(timeout: timeout), "The row's context menu has no Share")
        share.tap()

        let shareLink = app.buttons["Share link…"].firstMatch
        XCTAssertTrue(shareLink.waitUntilHittable(timeout: timeout), "The share menu has no Share link item")
        shareLink.tap()

        XCTAssertTrue(
            app.staticTexts["No share links yet"].waitForExistence(timeout: timeout),
            "The share links sheet did not open with an empty list"
        )

        // A menu picker is a button labelled with its title and current selection,
        // 7 days by default.
        let expiry = app.buttons["Expires, 7 days"].firstMatch
        XCTAssertTrue(expiry.waitUntilHittable(timeout: timeout), "The sheet has no expiry picker")
        expiry.tap()
        let never = app.buttons["Never"].firstMatch
        XCTAssertTrue(never.waitUntilHittable(timeout: timeout), "The expiry menu has no Never")
        never.tap()

        app.buttons["Create link"].firstMatch.tap()

        // The system share sheet shows up in this app's hierarchy. Its close button is addressed by
        // the identifier UIKit gives it: the app's own sheet has a "Close" button too, and by label
        // alone the two cannot be told apart.
        let activityList = app.otherElements["ActivityListView"]
        XCTAssertTrue(
            activityList.waitForExistence(timeout: timeout),
            "Creating a link did not open the system share sheet"
        )
        let close = app.buttons["header.closeButton"].firstMatch
        XCTAssertTrue(close.waitUntilHittable(timeout: timeout), "The system share sheet has no close button")
        close.tap()
        XCTAssertTrue(
            activityList.waitForNonExistence(timeout: timeout),
            "The system share sheet did not dismiss"
        )

        XCTAssertTrue(
            app.staticTexts["Never expires"].waitForExistence(timeout: timeout),
            "The created link was not listed with Never expires"
        )
        XCTAssertEqual(app.staticTexts.matching(identifier: "Never expires").count, 1)

        app.buttons["Delete"].firstMatch.tap()
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitUntilHittable(timeout: timeout), "Delete did not ask for confirmation")
        confirm.tap()

        XCTAssertTrue(
            app.staticTexts["No share links yet"].waitForExistence(timeout: timeout),
            "The list was not empty after deleting the link"
        )
        XCTAssertFalse(app.staticTexts["Never expires"].exists)
    }

    override func tearDown() async throws {
        if let documentId {
            try? await Fixtures.deleteDocument(id: documentId, token: user.token)
        }
        documentId = nil

        try await super.tearDown()
    }

    private var documentId: Document.Id?
}
