import UITestSupport
import XCTest

@MainActor
final class CustomFieldJourneyTests: UITestCase {

    // Custom fields carry no owner and are global to the instance, so unlike every other entity
    // these are visible to every other test. They are namespaced by name and never counted, and the
    // suite's orphan sweep removes any a failed run leaves behind.
    func testCustomFieldLifecycle() async throws {
        let list = try openCustomFields()
        let name = "\(user.namespace)-text"

        XCTAssertTrue(list.create(named: name), "Could not create \(name)")
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The created \(name) never appeared in the list"
        )
        XCTAssertTrue(
            app.staticTexts["Text · 0 documents"].firstMatch.exists,
            "The row did not describe the field as an empty Text field"
        )

        XCTAssertTrue(list.edit(named: name, appending: " Updated"), "Could not edit \(name)")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed \(name) never appeared in the list"
        )

        XCTAssertTrue(list.delete(named: "\(name) Updated"), "Could not delete \(name)")
    }

    // The select field is where the value is: it is the only form in the app with a nested
    // collection, and reopening it proves the options survived the round trip through extra_data.
    func testSelectCustomFieldRoundTripsItsOptions() async throws {
        let list = try openCustomFields()
        let form = CustomFieldFormScreen(app: app, timeout: timeout)
        let name = "\(user.namespace)-select"

        XCTAssertTrue(
            list.create(named: name) { _ in
                XCTAssertTrue(form.chooseDataType("Select"), "Could not choose the Select data type")
                XCTAssertTrue(form.addOption(labelled: "Open"), "Could not add the Open option")
            },
            "Could not create \(name)"
        )
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The created \(name) never appeared in the list"
        )

        let row = try XCTUnwrap(list.row(named: name), "The created \(name) went missing")
        app.tapSwipeAction("Edit custom field", in: row, timeout: timeout)

        XCTAssertEqual(
            form.firstOptionLabel(),
            "Open",
            "The option did not survive the round trip to the server"
        )

        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(list.delete(named: name), "Could not delete \(name)")
    }

    private func openCustomFields() throws -> EntityListScreen {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Custom fields"), "Could not open the Custom fields section")

        return EntityListScreen(app: app, entity: .customField, timeout: timeout)
    }
}
