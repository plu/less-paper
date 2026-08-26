import UITestSupport
import XCTest

// Captures the App Store screenshots. Not a test: nothing here asserts, and a failure means a
// screen could not be reached rather than that the app is wrong.
//
// It deliberately does not use UITestCase. That base class creates a real Paperless user, and a
// screenshot run must never reach a server - the app is launched on the fixtures in
// Screenshots/ instead, which is what SNAPSHOT_MODE selects.
// Matches SnapshotConfiguration.environmentKey. This target cannot import SnapshotSupport, which
// is DEBUG-only app code, so the two are kept in step by name.
enum SnapshotEnvironment {
    static let key = "SNAPSHOT_MODE"
}

@MainActor
final class SnapshotTests: XCTestCase {

    func testInbox() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: timeout))
        snapshot("01-Inbox")
    }

    func testDocuments() {
        let app = launch()
        XCTAssertTrue(documents(in: app).open(), "Could not open the Documents tab")
        snapshot("02-Documents")
    }

    func testSearch() {
        let app = launch()
        XCTAssertTrue(documents(in: app).open(), "Could not open the Documents tab")
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")
        snapshot("03-Search")
    }

    func testTags() {
        let app = launch()
        XCTAssertTrue(documents(in: app).open(), "Could not open the Documents tab")
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")

        // The tag field is the point of this screenshot, and it sits below the fold on a phone.
        let tags = app.buttons["Tags"].firstMatch
        XCTAssertTrue(tags.waitForExistence(timeout: timeout), "The filter sheet showed no tag field")
        tags.tap()
        snapshot("04-Tags")
    }

    func testView() {
        let app = launch()
        XCTAssertTrue(openFeaturedDocument(in: app), "Could not open the featured document")
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "The document detail never rendered a PDF"
        )
        snapshot("05-View")
    }

    func testEdit() {
        let app = launch()
        XCTAssertTrue(openFeaturedDocument(in: app), "Could not open the featured document")

        let edit = app.navigationBars.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitUntilHittable(timeout: timeout), "The detail screen showed no Edit button")
        edit.tap()
        XCTAssertTrue(
            app.staticTexts["Edit document"].waitForExistence(timeout: timeout),
            "The edit sheet never appeared"
        )
        snapshot("06-Edit")
    }

    func testSettings() {
        let app = launch()
        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        snapshot("07-Settings")
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Private

    private let timeout = 30.0

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)

        // Set here rather than left to the scheme: a scheme's test-action environment reaches the
        // test runner, not the app it launches. Without it the app opens on the add-server screen
        // and every screenshot fails looking for a tab bar.
        app.launchEnvironment[SnapshotEnvironment.key] = "true"

        app.launch()
        return app
    }

    private func documents(in app: XCUIApplication) -> DocumentListScreen {
        DocumentListScreen(app: app, timeout: timeout)
    }

    private func openFilter(in app: XCUIApplication) -> Bool {
        let filter = app.buttons["Filter"].firstMatch
        guard filter.waitUntilHittable(timeout: timeout) else {
            return false
        }
        filter.tap()
        return app.buttons["Apply"].firstMatch.waitForExistence(timeout: timeout)
    }

    // The first row rather than a title: the corpus differs by language, so naming a document here
    // would mean this file knowing which one each locale features.
    private func openFeaturedDocument(in app: XCUIApplication) -> Bool {
        guard documents(in: app).open() else {
            return false
        }
        let row = app.cells.firstMatch
        guard row.waitUntilHittable(timeout: timeout) else {
            return false
        }
        row.tap()
        return true
    }
}
