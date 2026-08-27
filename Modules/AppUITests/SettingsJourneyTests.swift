import UITestSupport
import XCTest

@MainActor
final class SettingsJourneyTests: UITestCase {

    func testSettingsListsEverySection() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")

        for section in [
            "Servers",
            "Correspondents",
            "Custom fields",
            "Document types",
            "PDF passwords",
            "Saved views",
            "Storage paths",
            "Tags",
            "Diagnostics",
            "Licenses"
        ] {
            XCTAssertTrue(
                settings.hasSection(section),
                "Missing settings section: \(section)"
            )
        }
    }
}
