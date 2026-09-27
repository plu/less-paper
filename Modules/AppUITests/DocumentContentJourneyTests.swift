import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class DocumentContentJourneyTests: UITestCase {

    // The content editor is a Runestone TextView, not a SwiftUI control, so nothing but a journey
    // shows that its edits reach the store: Reset has to write the saved text back into the view,
    // and Save has to send what was typed. Long content on purpose - that is what SwiftUI's
    // TextEditor could not handle, and the reason the editor was replaced.
    func testEditingLongContentPersistsIt() async throws {
        let title = "\(user.namespace)-content"
        documentId = try await Fixtures.uploadDocument(titled: title, token: user.token)
        let documentId = try XCTUnwrap(documentId)

        let content = (1 ... 2000)
            .map { "Line \($0): the quick brown fox jumps over the lazy dog" }
            .joined(separator: "\n")
        try await Fixtures.setContent(content, ofDocument: documentId, token: user.token)

        launch()

        let form = DocumentFormScreen(app: app, timeout: timeout)
        XCTAssertTrue(form.open(documentTitled: title), "Could not open the sheet for \(title)")
        XCTAssertTrue(form.openContentSection(), "Could not switch to the Content section")

        let editor = app.descendants(matching: .any)["DocumentContentEditor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: timeout), "The content editor never appeared")

        let save = app.buttons["Save"].firstMatch
        XCTAssertFalse(save.isEnabled, "Save was enabled before anything changed")

        editor.tap()
        app.typeText("XYZ")
        XCTAssertTrue(save.isEnabled, "Typing into the editor did not reach the store")

        app.buttons["Reset"].firstMatch.tap()
        XCTAssertFalse(save.isEnabled, "Reset did not put the saved content back")

        editor.tap()
        app.typeText("XYZ")
        save.tap()
        XCTAssertTrue(
            save.waitForNonExistence(timeout: timeout),
            "The sheet never closed after saving"
        )

        let saved = try await Fixtures.content(ofDocument: documentId, token: user.token)
        XCTAssertEqual(saved?.count, content.count + 3, "The saved content is not the original plus what was typed")
        XCTAssertTrue(saved?.contains("XYZ") == true, "The typed text was not saved")
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
