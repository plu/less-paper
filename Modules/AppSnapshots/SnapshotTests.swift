import UITestSupport
import XCTest

// Captures the App Store screenshots. Not a test: nothing here asserts about the app, and a failure
// means a screen could not be reached rather than that the app is wrong.
//
// It deliberately does not use UITestCase. That base class creates a real Paperless user, and a
// screenshot run must never reach a server - the app is launched on the fixtures in Screenshots/
// instead, which is what SNAPSHOT_MODE selects.
@MainActor
final class SnapshotTests: XCTestCase, UITestNavigation {

    func testInbox() {
        let app = launch()
        XCTAssertTrue(app.staticTexts[labels.inbox].waitForExistence(timeout: timeout))
        snapshot("01-Inbox")
    }

    func testDocuments() {
        let app = launch()
        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")
        snapshot("02-Documents")
    }

    func testSearch() {
        let app = launch()
        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")
        snapshot("03-Search")
    }

    func testTags() {
        let app = launch()
        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")

        // The tag field is a tap gesture rather than a button, so it is matched as a label.
        let tag = app.staticTexts[labels.tag].firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: timeout), "The filter sheet showed no tag field")
        tag.tap()

        XCTAssertTrue(
            app.buttons[labels.notAssigned].firstMatch.waitForExistence(timeout: timeout),
            "The tag sheet never appeared"
        )
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

        let edit = app.navigationBars.buttons[labels.edit].firstMatch
        XCTAssertTrue(edit.waitUntilHittable(timeout: timeout), "The detail screen showed no Edit button")
        edit.tap()
        XCTAssertTrue(
            app.staticTexts[labels.editDocument].waitForExistence(timeout: timeout),
            "The edit sheet never appeared"
        )
        snapshot("06-Edit")
    }

    // Waits on a row rather than the title: the list is seeded before launch, so the tab arrives
    // populated, and a title would be satisfied by the empty state too.
    func testOffline() {
        let app = launch()
        XCTAssertTrue(tapTab(labels.offline, in: app), "Could not open the Offline tab")
        XCTAssertTrue(
            app.cells.firstMatch.waitForExistence(timeout: timeout),
            "The Offline tab listed nothing"
        )
        snapshot("08-Offline")
    }

    func testSettings() {
        let app = launch()
        XCTAssertTrue(tapTab(labels.settings, in: app), "Could not open the Settings tab")
        XCTAssertTrue(
            app.staticTexts[labels.servers].waitForExistence(timeout: timeout),
            "Settings never listed its sections"
        )
        snapshot("07-Settings")
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // setupSnapshot fills Snapshot.deviceLanguage from the language fastlane is currently
    // capturing, so the labels follow the run rather than needing a switch of their own.
    var labels: SnapshotLabels {
        SnapshotLabels.current(Snapshot.deviceLanguage)
    }

    // MARK: - Private

    private func launch() -> XCUIApplication {
        let app = makeApp()
        setupSnapshot(app)
        app.launch()
        return app
    }
}
