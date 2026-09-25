import UITestSupport
import XCTest

final class SettingsJourneyTests: UITestCase {

    func testSettingsListsEverySection() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")

        // Alphabetical, not the order they appear in: which section a row is filed under is a
        // decision the settings screen is free to change, and a list written in screen order would
        // turn every such change into a failure here naming an unrelated row.
        let missing = settings.missingSections([
            "Correspondents",
            "Custom fields",
            "Diagnostics",
            "Document types",
            "Licenses",
            "PDF passwords",
            "Saved views",
            "Servers",
            "Storage paths",
            "Tags"
        ])

        XCTAssertTrue(
            missing.isEmpty,
            "Missing settings sections: \(missing.joined(separator: ", "))"
        )
    }
}
