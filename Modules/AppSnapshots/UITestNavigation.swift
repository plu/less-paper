import UITestSupport
import XCTest

// Matches SnapshotConfiguration.environmentKey. This target cannot import SnapshotSupport, which is
// DEBUG-only app code, so the two are kept in step by name.
enum SnapshotEnvironment {
    static let key = "SNAPSHOT_MODE"
}

// Shared by the two things that walk the app on fixtures: SnapshotTests, which stops on each screen
// to capture a frame, and AppPreviewTests, which walks straight through recording a video.
@MainActor
protocol UITestNavigation {
    var labels: SnapshotLabels { get }
}

@MainActor
extension UITestNavigation {

    var timeout: TimeInterval { 30.0 }

    // Returns the app unlaunched: SnapshotTests has to hand it to fastlane's setupSnapshot before
    // it starts, and AppPreviewTests must not, because no fastlane run is driving it.
    func makeApp() -> XCUIApplication {
        let app = XCUIApplication()

        // Set here rather than left to the scheme: a scheme's test-action environment reaches the
        // test runner, not the app it launches. Without it the app opens on the add-server screen
        // and every capture fails looking for a tab bar.
        app.launchEnvironment[SnapshotEnvironment.key] = "true"
        return app
    }

    // Not app.tabBars: iPadOS renders the tabs as a segmented bar along the top, which is not a tab
    // bar element, so a tab bar lookup finds nothing there. A plain button matches on both.
    func tapTab(_ label: String, in app: XCUIApplication) -> Bool {
        let tab = app.buttons[label].firstMatch
        guard tab.waitUntilHittable(timeout: timeout) else {
            return false
        }
        tab.tap()
        return true
    }

    // Waits on a document row rather than on any cell: the search field is a row of this list and
    // exists before a single document has arrived, so a cell is on screen the moment the tab is.
    func openDocuments(in app: XCUIApplication) -> Bool {
        guard tapTab(labels.documents, in: app) else {
            return false
        }
        return app.documentRows.firstMatch.waitForExistence(timeout: timeout)
    }

    func openFilter(in app: XCUIApplication) -> Bool {
        let filter = app.buttons[labels.filter].firstMatch
        guard filter.waitUntilHittable(timeout: timeout) else {
            return false
        }
        filter.tap()

        // The search field rather than the Apply button: it is the element the sheet is built
        // around, and it is present as soon as the sheet is.
        return app.textFields[labels.titleAndContent].firstMatch.waitForExistence(timeout: timeout)
    }

    // The first document row rather than a title: the corpus differs by language, and
    // SnapshotCorpus puts the document these two screenshots want at the top for exactly this
    // reason. Not the first *cell* — that is the search field.
    func openFeaturedDocument(in app: XCUIApplication) -> Bool {
        guard openDocuments(in: app) else {
            return false
        }
        let row = app.documentRows.firstMatch
        guard row.waitUntilHittable(timeout: timeout) else {
            return false
        }
        row.tap()
        return true
    }
}
