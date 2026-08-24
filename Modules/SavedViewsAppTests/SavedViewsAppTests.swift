@testable import ApiImplementation

import ApiInterface
import Dependencies
import SavedViewsFeature
import UITestSupport
import XCTest

@MainActor
final class SavedViewsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllSavedViews()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add saved view"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New Saved View")
        app.switches["Show in sidebar"].tap()
        app.switches["Show on dashboard"].tap()
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Saved View"].waitForExistence(timeout: timeout))

        let cell = app.cells.containing(.staticText, identifier: "New Saved View").firstMatch
        XCTAssertTrue(cell.images["Show in sidebar"].exists)
        XCTAssertTrue(cell.images["Show on dashboard"].exists)
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete saved view", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Saved View\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllSavedViews()
        }

        app.tapSwipeAction("Delete saved view", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Saved View\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No SavedView matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        let cell = app.cells.containing(.staticText, identifier: "Test Saved View").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: timeout))
        XCTAssertTrue(cell.images["Show in sidebar"].exists)
        XCTAssertTrue(cell.images["Show on dashboard"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit saved view", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Saved View Updated"].waitForExistence(timeout: timeout))

        let cell = app.cells.containing(.staticText, identifier: "Test Saved View Updated").firstMatch
        XCTAssertTrue(cell.images["Show in sidebar"].exists)
        XCTAssertTrue(cell.images["Show on dashboard"].exists)
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllSavedViews()
            try await createTestSavedView()
        }

        continueAfterFailure = false
    }

    private func createTestSavedView() async throws {
        @Dependency(\.saveSavedView.execute)
        var saveSavedView

        _ = try await saveSavedView(
            nil,
            .init(
                name: "Test Saved View",
                showInSidebar: true,
                showOnDashboard: true
            ),
            server
        )
    }

    private func deleteAllSavedViews() async throws {
        @Dependency(\.savedViewsRepository)
        var savedViewsRepository

        let savedViews = try await savedViewsRepository.getSavedViews(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for savedView in savedViews {
            try await savedViewsRepository.deleteSavedView(
                id: savedView,
                server: server
            )
        }
    }

    @discardableResult
    public func withTestDependencies<R>(
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> R
    ) async rethrows -> R {
        try await withDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        } operation: {
            try await operation()
        }
    }

    private let server = Server.testValue()
    private let timeout = 5.0
}
