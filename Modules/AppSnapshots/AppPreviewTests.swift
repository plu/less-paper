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

        // The same two arguments fastlane's setupSnapshot passes for a screenshot run, set here
        // because no fastlane run is driving this one. Without them the app opens in whatever
        // language the simulator happens to be in, and every label lookup below misses.
        // -AppleLocale wants de_DE where App Store Connect's directory wants de-DE.
        let appleLocale = locale.replacingOccurrences(of: "-", with: "_")
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", appleLocale]
        app.launch()

        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")

        // Announced so the recorder can check it got what it asked for. PREVIEW_LOCALE arrives
        // through xcodebuild's environment, and when that plumbing breaks the default silently
        // takes over: the app launches in English, the English labels all match, the test passes,
        // and an English video lands in a German directory.
        // The custom `print` rule's regex is greedy and matches from the first print in the file
        // onwards, so this one disable covers every deliberate print here; a second would be
        // flagged superfluous and --strict makes that an error.
        // swiftlint:disable:next print
        print("PREVIEW_LOCALE \(locale)")

        let start = Date()
        mark("start", at: start)

        // Beat 1 - the list, held just long enough to read. There was a scroll here; it cost 3.5
        // seconds to move the list by one row, which is the slowest-feeling thing a viewer can be
        // shown first. openDocuments has already put the list on screen, so a beat of stillness
        // establishes it and the filter sheet arrives while the viewer is still interested.
        hold(until: 1, from: start, beat: "list")

        // Beat 2 - the filter sheet.
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")
        hold(until: 6, from: start, beat: "filter")

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
        hold(until: 8, from: start, beat: "search")

        // Beat 4 - back to the narrowed list. There is no Apply button: the filter applies live, so
        // closing the sheet is what reveals the result.
        closeSheet(in: app)
        XCTAssertTrue(app.documentRows.firstMatch.waitForExistence(timeout: timeout), "The filtered list came back empty")
        hold(until: 12, from: start, beat: "filtered")

        // Beat 5 - a document, open.
        let row = app.documentRows.firstMatch
        XCTAssertTrue(row.waitUntilHittable(timeout: timeout), "The filtered list had no tappable row")
        row.tap()
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "The document detail never rendered a PDF"
        )
        hold(until: 17, from: start, beat: "pdf")

        // Beat 6 - editing it where it is being read.
        let edit = app.navigationBars.buttons[labels.edit].firstMatch
        XCTAssertTrue(edit.waitUntilHittable(timeout: timeout), "The detail screen showed no Edit button")
        edit.tap()
        XCTAssertTrue(
            app.staticTexts[labels.editDocument].waitForExistence(timeout: timeout),
            "The edit sheet never appeared"
        )
        hold(until: 21, from: start, beat: "edit")

        // Beat 7 - back to the document, and rest there. The last frame is the one a viewer is left
        // with, so it is the document rather than a form.
        closeSheet(in: app)
        hold(until: 24, from: start, beat: "rest")

        mark("end", at: Date())
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // Asked for directly rather than through Snapshot.deviceLanguage, which is empty when no
    // fastlane run is driving. Not private: UITestNavigation requires it.
    var labels: SnapshotLabels {
        SnapshotLabels.current(language)
    }

    // Which language to record. Set by mise/tasks/preview/record through TEST_RUNNER_PREVIEW_LOCALE,
    // which is how xcodebuild passes an environment variable into the test runner's own process
    // rather than into the app it launches. Defaults to en-US so running the test from Xcode with
    // nothing configured still works.
    var locale: String {
        ProcessInfo.processInfo.environment["PREVIEW_LOCALE"] ?? "en-US"
    }

    // "de-DE" -> "de". -AppleLanguages wants the language, SnapshotLabels.current matches on its
    // prefix, and App Store Connect wants the full locale for the directory name.
    var language: String {
        String(locale.prefix(while: { $0 != "-" }))
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
            //
            // An overrun here is a signal to retune the marks, and stdout is the only place it can
            // be seen from outside the process.
            print("PREVIEW_OVERRUN \(beat) \(-remaining)")
            return
        }
        Thread.sleep(forTimeInterval: remaining)
    }

    private func mark(_ name: String, at date: Date) {
        // This line is the recorder's only way to know when the choreography began and ended:
        // simctl and xcodebuild are stitched together by these markers, not by assumption.
        print("PREVIEW_MARKER \(name) \(date.timeIntervalSince1970)")
    }

    private func closeSheet(in app: XCUIApplication) {
        let close = app.buttons[labels.close].firstMatch
        XCTAssertTrue(close.waitUntilHittable(timeout: timeout), "No close button on the sheet")
        close.tap()
    }
}
