@testable import ApiImplementation

import ApiInterface
import CorrespondentsFeature
import Dependencies
import UITestSupport
import XCTest

@MainActor
final class CorrespondentsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllCorrespondents()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add correspondent"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New Correspondent")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Correspondent"].waitForExistence(timeout: timeout))
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete correspondent", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Correspondent\"?"].waitForExistence(timeout: timeout))
        app.sheets.buttons["Delete correspondent"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllCorrespondents()
        }

        app.tapSwipeAction("Delete correspondent", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Correspondent\"?"].waitForExistence(timeout: timeout))
        app.sheets.buttons["Delete correspondent"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No Correspondent matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Test Correspondent"].exists)
        XCTAssertTrue(app.staticTexts["0 documents"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit correspondent", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Correspondent Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllCorrespondents()
            try await createTestCorrespondent()
        }

        continueAfterFailure = false
    }

    private func createTestCorrespondent() async throws {
        @Dependency(\.correspondentsRepository)
        var correspondentsRepository

        _ = try await correspondentsRepository.createCorrespondent(
            input: .init(
                name: "Test Correspondent"
            ),
            server: server
        )
    }

    private func deleteAllCorrespondents() async throws {
        @Dependency(\.correspondentsRepository)
        var correspondentsRepository

        let correspondents = try await correspondentsRepository.getCorrespondents(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for correspondent in correspondents {
            try await correspondentsRepository.deleteCorrespondent(
                id: correspondent,
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
