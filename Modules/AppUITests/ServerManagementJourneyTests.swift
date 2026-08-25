import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class ServerManagementJourneyTests: UITestCase {

    // Journey 1 drives adding the first server for real; this one starts from the seeded server and
    // covers what follows it.
    //
    // The seeded server is never deleted: it is the one the app is running on, so removing it logs
    // the app out and the harness's "No servers found" empty state is unreachable from here. That
    // the surviving server is untouched by its neighbour's deletion is the assertion that carries
    // over to real use.
    func testAddingSwitchingEditingAndDeletingASecondServer() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Servers"), "Could not open the Servers section")

        let form = ServerFormScreen(app: app, timeout: timeout)
        let seeded = Server.testValue().alias
        let second = "\(user.namespace)-second"

        XCTAssertTrue(
            try form.addServer(
                alias: second,
                url: .testValue(),
                username: user.namespace,
                password: user.password
            ),
            "The add-server form did not complete for \(second)"
        )

        XCTAssertTrue(
            app.staticTexts[second].waitForExistence(timeout: timeout),
            "The second server never appeared in the list"
        )
        XCTAssertTrue(
            app.staticTexts["\(user.namespace) @ \(URL.testValue().absoluteString)"].firstMatch.exists,
            "The second server's row carried no username @ url subtitle"
        )

        // Each switch empties the settings stack, so the section has to be reopened every time.
        XCTAssertTrue(select(server: second), "Could not switch to \(second)")
        XCTAssertTrue(settings.openSection("Servers"), "Could not reopen the Servers section")

        XCTAssertTrue(select(server: seeded), "Could not switch back to \(seeded)")
        XCTAssertTrue(settings.openSection("Servers"), "Could not reopen the Servers section")

        let secondRow = try XCTUnwrap(row(named: second), "The second server row went missing")
        app.tapSwipeAction("Edit server", in: secondRow, timeout: timeout)
        XCTAssertTrue(form.editAlias(appending: " Updated"), "Could not edit the alias of \(second)")
        XCTAssertTrue(
            app.staticTexts["\(second) Updated"].waitForExistence(timeout: timeout),
            "The renamed server never appeared in the list"
        )

        let renamedRow = try XCTUnwrap(row(named: "\(second) Updated"), "The renamed row went missing")
        app.tapSwipeAction("Delete server", in: renamedRow, timeout: timeout)
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "No delete confirmation appeared")
        confirm.tap()

        XCTAssertTrue(
            app.staticTexts["\(second) Updated"].waitForNonExistence(timeout: timeout),
            "The deleted server stayed in the list"
        )
        XCTAssertTrue(
            app.staticTexts[seeded].exists,
            "Deleting the second server took the seeded one with it"
        )
    }

    private func row(named alias: String) -> XCUIElement? {
        let row = app.cells.containing(.staticText, identifier: alias).firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            return nil
        }
        return row
    }

    // Called with the Servers list on screen. Selecting writes `selectedServer`, which rebuilds
    // MainReducer.State and empties the settings navigation stack this row lives in — the app lands
    // back on the main screen, as ServerRowReducer+Effect describes. So the switch is observed by
    // reopening Settings, whose root renders username@alias for whichever server is now active. The
    // row's own checkmark carries no label to match on.
    private func select(server alias: String) -> Bool {
        guard let row = row(named: alias) else {
            return false
        }
        row.tap()

        let settings = SettingsScreen(app: app, timeout: timeout)
        guard settings.open() else {
            return false
        }
        return app.staticTexts["\(user.namespace)@\(alias)"].waitForExistence(timeout: timeout)
    }
}
