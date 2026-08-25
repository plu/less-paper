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

    override func tearDown() async throws {
        if let fieldId {
            try? await Fixtures.deleteCustomField(id: fieldId)
        }
        fieldId = nil

        try await super.tearDown()
    }

    private var fieldId: CustomField.Id?
}
