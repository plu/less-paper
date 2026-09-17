import UITestSupport
import XCTest

// Records the App Store preview. Not a test: nothing here asserts about the app, and a failure means
// a beat could not be reached rather than that the app is wrong.
//
// The recording is taken from outside by mise/tasks/preview/record, which cannot see inside the
// simulator. This side's whole contract with it is the two marker lines: everything between them is
// the video.
@MainActor
final class AppPreviewTests: XCTestCase, UITestNavigation {

    func testRecordPreview() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")

        let start = Date()
        mark("start", at: start)

        // Beat 1 - the list, scrolled. press-then-drag rather than swipeUp: a swipe is flung and
        // lands in a blur, which reads as a glitch at thumbnail size.
        //
        // Coordinates rather than elements: a drag from a cell to itself covers no distance and
        // scrolls nothing, and the cell that starts under the finger is not the one that ends there.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        from.press(forDuration: 0.3, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        hold(until: 3, from: start, beat: "list")

        // Beat 2 - the filter sheet.
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")
        hold(until: 7, from: start, beat: "filter")

        // Beat 3 - a search typed into the field the sheet is already built around. openFilter(in:)
        // only returns once this field exists, so it is present here without a further wait.
        //
        // Not localised: like the tag it replaced, "Sonos" is server data, from
        // SnapshotCorpus.documentIds rather than Screenshots/Fixtures/documents.json - the snapshot
        // stub serves that fixed eight-document corpus regardless of locale. It matches 2 of the 8
        // (Sonos Era 300, Sonos Sub), which narrows the list visibly without emptying it - and it
        // removes a whole sheet round trip that the tag picker cost, which is what made the original
        // beat sheet unbuildable inside Apple's 30s ceiling.
        let searchField = app.textFields[labels.titleAndContent].firstMatch
        searchField.tap()
        searchField.typeText("Sonos")
        hold(until: 11, from: start, beat: "search")

        // Beat 4 - back to the narrowed list. There is no Apply button: the filter applies live, so
        // closing the sheet is what reveals the result.
        closeSheet(in: app)
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout), "The filtered list came back empty")
        hold(until: 15, from: start, beat: "filtered")

        // Beat 5 - a document, open.
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitUntilHittable(timeout: timeout), "The filtered list had no tappable row")
        row.tap()
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "The document detail never rendered a PDF"
        )
        hold(until: 20, from: start, beat: "pdf")

        // Beat 6 - editing it where it is being read.
        let edit = app.navigationBars.buttons[labels.edit].firstMatch
        XCTAssertTrue(edit.waitUntilHittable(timeout: timeout), "The detail screen showed no Edit button")
        edit.tap()
        XCTAssertTrue(
            app.staticTexts[labels.editDocument].waitForExistence(timeout: timeout),
            "The edit sheet never appeared"
        )
        hold(until: 24, from: start, beat: "edit")

        // Beat 7 - back to the document, and rest there. The last frame is the one a viewer is left
        // with, so it is the document rather than a form.
        closeSheet(in: app)
        hold(until: 27, from: start, beat: "rest")

        mark("end", at: Date())
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // One locale, so the label table is asked for it directly rather than through
    // Snapshot.deviceLanguage, which is empty when no fastlane run is driving. Not private:
    // UITestNavigation requires it.
    var labels: SnapshotLabels {
        SnapshotLabels.english
    }

    // MARK: - Private

    // Beats are scheduled against the start, never chained. Chaining would make the total duration
    // the sum of the dwells *plus* however long six screens took to settle, which on a loaded runner
    // is a coin flip against the 30s ceiling. Scheduling puts the cost of a slow settle inside that
    // beat's own slot: the video still ends at 0:27, that beat is just held for less.
    private func hold(until elapsed: TimeInterval, from start: Date, beat: String) {
        let remaining = elapsed - Date().timeIntervalSince(start)
        guard remaining > 0 else {
            // Logged, not failed: one overrun beat still yields a usable video, and the number is
            // what the marks get retuned against. An overrun big enough to matter fails later, when
            // preview_window.py finds the run outside 15-30s.
            print("PREVIEW_OVERRUN \(beat) \(-remaining)")
            return
        }
        Thread.sleep(forTimeInterval: remaining)
    }

    private func mark(_ name: String, at date: Date) {
        print("PREVIEW_MARKER \(name) \(date.timeIntervalSince1970)")
    }

    private func closeSheet(in app: XCUIApplication) {
        let close = app.buttons[labels.close].firstMatch
        XCTAssertTrue(close.waitUntilHittable(timeout: timeout), "No close button on the sheet")
        close.tap()
    }
}
