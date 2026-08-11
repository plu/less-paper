@testable import ApiImplementation

import ApiInterface
import Dependencies
import TagsFeature
import UITestSupport
import XCTest

@MainActor
final class TagsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllTags()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add tag"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New tag")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New tag"].waitForExistence(timeout: timeout))
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete tag", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Inbox\"?"].waitForExistence(timeout: timeout))
        app.sheets.buttons["Delete tag"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllTags()
        }

        app.tapSwipeAction("Delete tag", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Inbox\"?"].waitForExistence(timeout: timeout))
        app.sheets.buttons["Delete tag"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No Tag matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Inbox"].exists)
        XCTAssertTrue(app.staticTexts["0 documents"].exists)
        XCTAssertTrue(app.staticTexts["#aa0000"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit tag", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Inbox Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllTags()
            try await createTestTag()
        }

        continueAfterFailure = false
    }

    private func createTestTag() async throws {
        @Dependency(\.tagsRepository)
        var tagsRepository

        _ = try await tagsRepository.createTag(
            input: .init(
                color: "#aa0000",
                isInboxTag: true,
                name: "Inbox"
            ),
            server: server
        )
    }

    private func deleteAllTags() async throws {
        @Dependency(\.tagsRepository)
        var tagsRepository

        let tags = try await tagsRepository.getTags(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for tag in tags {
            try await tagsRepository.deleteTag(
                id: tag,
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
