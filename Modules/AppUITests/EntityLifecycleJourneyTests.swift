import UITestSupport
import XCTest

@MainActor
final class EntityLifecycleJourneyTests: UITestCase {

    func testCorrespondentLifecycle() async throws {
        runLifecycle(for: .correspondent, section: "Correspondents")
    }

    func testDocumentTypeLifecycle() async throws {
        runLifecycle(for: .documentType, section: "Document types")
    }

    // The one lifecycle that does not call runLifecycle: the badges have to be asserted between
    // creation and edit, and runLifecycle deletes the row at the end, so a check placed after it
    // could only prove absence.
    func testSavedViewLifecycle() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Saved views"), "Could not open the Saved views section")

        let list = EntityListScreen(app: app, entity: .savedView, timeout: timeout)
        let name = "\(user.namespace)-saved-view"

        XCTAssertTrue(
            list.create(named: name) { _ in
                app.switches["Show in sidebar"].tap()
                app.switches["Show on dashboard"].tap()
            },
            "Could not create \(name)"
        )

        // The badges are the only per-entity detail any lifecycle journey asserts: both switches
        // were on at creation, so both images must be on the row.
        let row = try XCTUnwrap(list.row(named: name), "The created \(name) never appeared")
        XCTAssertTrue(row.images["Show in sidebar"].exists)
        XCTAssertTrue(row.images["Show on dashboard"].exists)

        XCTAssertTrue(list.edit(named: name, appending: " Updated"), "Could not edit \(name)")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed \(name) never appeared in the list"
        )

        XCTAssertTrue(list.delete(named: "\(name) Updated"), "Could not delete \(name)")
    }

    func testStoragePathLifecycle() async throws {
        runLifecycle(for: .storagePath, section: "Storage paths") { list in
            // Paperless rejects a storage path with no path, so this one is required rather than
            // decorative - create() returns false without it.
            list.type("/home/paperless/\(user.namespace)", into: "Path")
        }
    }

    func testTagLifecycle() async throws {
        runLifecycle(for: .tag, section: "Tags")
    }

    func testDeletingATagRemovedServerSideSurfacesTheConflict() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Tags"), "Could not open the Tags section")

        let list = EntityListScreen(app: app, entity: .tag, timeout: timeout)
        let name = "\(user.namespace)-stale"

        XCTAssertTrue(list.create(named: name), "Could not create \(name)")
        let row = try XCTUnwrap(list.row(named: name), "The created \(name) never appeared")

        try await Fixtures.deleteTag(named: name)

        app.tapSwipeAction("Delete tag", in: row, timeout: timeout)
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "No delete confirmation appeared")
        confirm.tap()

        XCTAssertTrue(
            app.otherElements["Toast"].waitForExistence(timeout: timeout),
            "The failed delete surfaced no toast"
        )

        // The row must outlive the failed delete. Removing it optimistically would report a success
        // the server never granted.
        XCTAssertTrue(
            app.staticTexts[name].exists,
            "The row disappeared even though the delete failed"
        )
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
