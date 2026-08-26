import UITestSupport
import XCTest

// Matches SnapshotConfiguration.environmentKey. This target cannot import SnapshotSupport, which is
// DEBUG-only app code, so the two are kept in step by name.
enum SnapshotEnvironment {
    static let key = "SNAPSHOT_MODE"
}

// Captures the App Store screenshots. Not a test: nothing here asserts about the app, and a failure
// means a screen could not be reached rather than that the app is wrong.
//
// It deliberately does not use UITestCase. That base class creates a real Paperless user, and a
// screenshot run must never reach a server - the app is launched on the fixtures in Screenshots/
// instead, which is what SNAPSHOT_MODE selects.
@MainActor
final class SnapshotTests: XCTestCase {

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

    // MARK: - Private

    private let timeout = 30.0

    // setupSnapshot fills Snapshot.deviceLanguage from the language fastlane is currently
    // capturing, so the labels follow the run rather than needing a switch of their own.
    private var labels: SnapshotLabels {
        SnapshotLabels.current(Snapshot.deviceLanguage)
    }

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

    private func openDocuments(in app: XCUIApplication) -> Bool {
        guard tapTab(labels.documents, in: app) else {
            return false
        }
        return app.cells.firstMatch.waitForExistence(timeout: timeout)
    }

    // Not app.tabBars: iPadOS renders the tabs as a segmented bar along the top, which is not a tab
    // bar element, so a tab bar lookup finds nothing there. A plain button matches on both.
    private func tapTab(_ label: String, in app: XCUIApplication) -> Bool {
        let tab = app.buttons[label].firstMatch
        guard tab.waitUntilHittable(timeout: timeout) else {
            return false
        }
        tab.tap()
        return true
    }

    private func openFilter(in app: XCUIApplication) -> Bool {
        let filter = app.buttons[labels.filter].firstMatch
        guard filter.waitUntilHittable(timeout: timeout) else {
            return false
        }
        filter.tap()

        // The search field rather than the Apply button: it is the element the sheet is built
        // around, and it is present as soon as the sheet is.
        return app.textFields[labels.titleAndContent].firstMatch.waitForExistence(timeout: timeout)
    }

    // The first row rather than a title: the corpus differs by language, and SnapshotCorpus puts
    // the document these two screenshots want at the top for exactly this reason.
    private func openFeaturedDocument(in app: XCUIApplication) -> Bool {
        guard openDocuments(in: app) else {
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
