import UITestSupport
import XCTest

@MainActor
final class EntityLifecycleJourneyTests: UITestCase {

    func testCorrespondentLifecycle() async throws {
        runLifecycle(for: .correspondent, section: "Correspondents")
    }

    func testTagLifecycle() async throws {
        runLifecycle(for: .tag, section: "Tags")
    }

    // The test user owns nothing at start, so every list here opens empty and no method can see
    // another's rows.
    private func runLifecycle(
        for entity: EntityListScreen.Entity,
        section: String,
        extras: (EntityListScreen) -> Void = { _ in }
    ) {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection(section), "Could not open the \(section) section")

        let list = EntityListScreen(app: app, entity: entity, timeout: timeout)
        let name = "\(user.namespace)-\(section.lowercased().replacingOccurrences(of: " ", with: "-"))"

        XCTAssertTrue(list.create(named: name, extras: extras), "Could not create \(name)")
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The created \(name) never appeared in the list"
        )

        XCTAssertTrue(list.edit(named: name, appending: " Updated"), "Could not edit \(name)")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed \(name) never appeared in the list"
        )

        XCTAssertTrue(list.delete(named: "\(name) Updated"), "Could not delete \(name)")
    }
}
