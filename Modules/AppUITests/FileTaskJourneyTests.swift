import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class FileTaskJourneyTests: UITestCase {

    // On the owner scoping of /api/tasks/, checked against the dev instance before this was written:
    // a freshly created non-superuser sees its own tasks plus every task owned by nobody — never
    // another user's. So the endpoint IS scoped, but not to "your own tasks": paperless-ngx's normal
    // owner-or-unowned object filtering applies to tasks too, and the docker/consume corpus is
    // unowned by design (see AGENTS.md), so it is always part of what a fresh user sees here. This
    // journey therefore cannot assume the Complete list is short, or that it holds only its own row.
    //
    // Two things make that worse than it sounds. Paperless records the *uploaded file's* name on a
    // consume task, not the document title, so every upload of the shared fixture PDF is called
    // "Sonos One.pdf" — the corpus's own copy included — which is why this uploads a copy named
    // after the test user instead (Fixtures.uploadDocument(fileNamed:)). And a task record outlives
    // everything the journey can clean up: deleting the document leaves it, and deleting its owner
    // only sets its owner to null, so every past run's task stays in this list forever, visible to
    // every later user. A per-run file name is the only thing that tells this run's row apart from
    // all of them.
    func testUploadingAndDismissingAFileTask() async throws {
        // No space in the name on purpose: the multipart encoder percent-encodes the file name it
        // sends, so a fixture uploaded under its own name shows up as "Sonos%20One.pdf" in this
        // list. That is a pre-existing quirk of the upload path, not something to work around here.
        let fileName = "\(user.namespace)-file-task.pdf"
        documentId = try await Fixtures.uploadDocument(
            titled: "\(user.namespace)-file-task",
            fileNamed: fileName,
            token: user.token
        )

        launch()

        let inboxTab = app.tabBars.buttons["Inbox"]
        XCTAssertTrue(inboxTab.waitUntilHittable(timeout: timeout), "Could not open the Inbox tab")
        inboxTab.tap()

        // Hidden entirely without viewPaperlessTask. The test user is created with every
        // permission, so a missing button here means the toolbar, not the user.
        let fileTasksButton = app.buttons["File Tasks"]
        XCTAssertTrue(
            fileTasksButton.waitUntilHittable(timeout: timeout),
            "The File Tasks button never appeared in the inbox toolbar"
        )
        fileTasksButton.tap()

        XCTAssertTrue(
            app.staticTexts["File Tasks"].waitForExistence(timeout: timeout),
            "The File Tasks sheet never opened"
        )

        // By label, never by index: the segments are ordered Failed, Complete, Started, Queued, and
        // the sheet opens on Failed whenever the badge count is above zero.
        let completeSegment = app.segmentedControls.buttons["Complete"]
        XCTAssertTrue(
            completeSegment.waitUntilHittable(timeout: timeout),
            "The Complete segment never appeared"
        )
        completeSegment.tap()

        // Consumption is asynchronous, so this waits for the row rather than assuming the upload is
        // already listed by the time the sheet opens.
        let row = app.cells.containing(.staticText, identifier: fileName).firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: timeout),
            "The uploaded file never appeared under Complete"
        )

        app.tapSwipeAction("Dismiss", in: row, timeout: timeout)

        // The row is removed only once the server has acknowledged the task — a failed dismiss
        // leaves it standing and raises a toast — so its disappearance is the server's answer, not
        // an optimistic one.
        XCTAssertTrue(
            app.staticTexts[fileName].waitForNonExistence(timeout: timeout),
            "Dismissing the row did not remove it from the list"
        )
    }

    // Deleting the user does not cascade to the document it uploaded, so this goes first.
    override func tearDown() async throws {
        if let documentId {
            try? await Fixtures.deleteDocument(id: documentId, token: user.token)
        }
        documentId = nil

        try await super.tearDown()
    }

    private var documentId: Document.Id?
}
