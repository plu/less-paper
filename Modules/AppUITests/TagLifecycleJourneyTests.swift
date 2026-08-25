import UITestSupport
import XCTest

@MainActor
final class TagLifecycleJourneyTests: UITestCase {

    // The test user owns nothing at start, so the list opens empty and no fixture teardown is
    // needed to keep the next test honest.
    func testCreateEditAndDeleteATag() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Tags"), "Could not open the Tags section")

        let tags = TagListScreen(app: app, timeout: timeout)
        let name = "\(user.namespace)-tag"

        XCTAssertTrue(tags.createTag(named: name), "Could not create the tag \(name)")
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The created tag \(name) never appeared in the list"
        )

        XCTAssertTrue(tags.editTag(named: name, appending: " Updated"), "Could not edit the tag")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed tag never appeared in the list"
        )

        XCTAssertTrue(tags.deleteTag(named: "\(name) Updated"), "Could not delete the tag")
    }
}
