import UITestSupport
import XCTest

@MainActor
final class DocumentBrowsingJourneyTests: UITestCase {

    // Reads the shared corpus and modifies nothing. Documents consumed from docker/consume/ have no
    // owner, so every test sees the same ones — which is what makes filtering assertable by title
    // here, and why nothing in this journey may write.
    func testFilteringTheCorpusAndOpeningADocument() async throws {
        launch()

        let documents = DocumentListScreen(app: app, timeout: timeout)
        XCTAssertTrue(documents.open(), "Could not open the Documents tab")

        XCTAssertTrue(documents.filter(byTitle: "Lego"), "Could not filter the list by title")
        XCTAssertTrue(
            app.staticTexts["Lego Duplo"].waitForExistence(timeout: timeout),
            "Filtering by Lego did not leave Lego Duplo in the list"
        )
        XCTAssertTrue(
            app.staticTexts["Lego Friends"].exists,
            "Filtering by Lego did not leave Lego Friends in the list"
        )
        XCTAssertTrue(
            app.staticTexts["2 of 2 loaded"].waitForExistence(timeout: timeout),
            "The filtered list did not report two documents"
        )

        XCTAssertTrue(documents.open(documentTitled: "Lego Duplo"), "Could not open Lego Duplo")
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "The document detail screen never rendered a PDF"
        )

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Lego Friends"].waitForExistence(timeout: timeout),
            "Going back did not return to the filtered list"
        )
    }
}
