import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class OnboardingJourneyTests: UITestCase {

    // The one journey that launches without a seeded server: it drives the real form, the real
    // version negotiation, and the real credential write that every other journey skips.
    func testAddingAServerReachesTheMainScreen() async throws {
        launch(seedingServer: false)

        let form = ServerFormScreen(app: app, timeout: timeout)

        XCTAssertTrue(
            try form.addServer(
                alias: user.namespace,
                url: .testValue(),
                username: user.namespace,
                password: user.password
            ),
            "The add-server form did not complete"
        )

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: timeout),
            "Adding a server did not land on the main screen"
        )

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")

        XCTAssertTrue(
            app.staticTexts["\(user.namespace)@\(user.namespace)"].waitForExistence(timeout: timeout),
            "Settings did not show the signed-in user \(user.namespace)"
        )
    }
}
