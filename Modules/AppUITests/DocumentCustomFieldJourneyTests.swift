import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class DocumentCustomFieldJourneyTests: UITestCase {

    // Guards the regression fixed in #192: the tap dispatched, the reducer set the destination and
    // the reducer test passed — but no view presented the picker, so the field looked dead. Only a
    // test that drives the assembled app can see that.
    func testTappingADocumentLinkFieldOpensThePicker() async throws {
        let name = "\(user.namespace)-link"
        fieldId = try await Fixtures.createCustomField(name: name, dataType: .documentLink)

        launch()

        let form = DocumentFormScreen(app: app, timeout: timeout)
        XCTAssertTrue(form.openFromDocumentList(), "Could not open the edit sheet for a document")
        XCTAssertTrue(form.openCustomFieldsSection(), "Could not switch to the Custom fields section")
        XCTAssertTrue(form.attachCustomField(named: name), "Could not attach the custom field \(name)")

        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The attached field \(name) never appeared in the form"
        )

        app.staticTexts[name].firstMatch.tap()

        // The picker is the only sheet in this flow carrying a search field, so this cannot be
        // satisfied by the document list behind it the way its "Documents" title could.
        XCTAssertTrue(
            app.searchFields.firstMatch.waitForExistence(timeout: timeout),
            "Tapping a document-link field did not open the document picker"
        )
    }

    // The corpus is shared and unowned, so a journey that *writes* a field value has to bring its
    // own document. This one uploads a PDF as the test user, which makes it owned and invisible to
    // every other test, and deletes it again in tearDown — user deletion does not cascade to it.
    func testEditingACustomFieldValuePersistsIt() async throws {
        let name = "\(user.namespace)-value"
        fieldId = try await Fixtures.createCustomField(name: name, dataType: .string)

        let title = "\(user.namespace)-doc"
        documentId = try await Fixtures.uploadDocument(titled: title, token: user.token)

        launch()

        let form = DocumentFormScreen(app: app, timeout: timeout)
        XCTAssertTrue(form.open(documentTitled: title), "Could not open the edit sheet for \(title)")
        XCTAssertTrue(form.openCustomFieldsSection(), "Could not switch to the Custom fields section")
        XCTAssertTrue(form.attachCustomField(named: name), "Could not attach the custom field \(name)")

        let value = app.textFields[name].firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: timeout), "The attached field had no editor")
        value.tap()
        app.typeText("42")

        app.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["Save"].firstMatch.waitForNonExistence(timeout: timeout),
            "The document form never closed after saving"
        )

        XCTAssertTrue(form.open(documentTitled: title), "Could not reopen the edit sheet for \(title)")
        XCTAssertTrue(form.openCustomFieldsSection(), "Could not switch back to the Custom fields section")

        let saved = app.textFields[name].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: timeout), "The saved field was not attached")
        XCTAssertEqual(saved.value as? String, "42", "The custom field value did not persist")
    }

    override func tearDown() async throws {
        if let documentId {
            try? await Fixtures.deleteDocument(id: documentId, token: user.token)
        }
        documentId = nil

        if let fieldId {
            try? await Fixtures.deleteCustomField(id: fieldId)
        }
        fieldId = nil

        try await super.tearDown()
    }

    private var documentId: Document.Id?

    private var fieldId: CustomField.Id?
}
