@testable import ApiImplementation

import ApiInterface
import Dependencies
import StoragePathsFeature
import UITestSupport
import XCTest

@MainActor
final class StoragePathsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllStoragePaths()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add storage path"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New Storage Path")
        app.textFields["Path"].tap()
        app.typeText("/home/paperless/new-storage-path")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Storage Path"].waitForExistence(timeout: timeout))
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete storage path", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Storage Path\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllStoragePaths()
        }

        app.tapSwipeAction("Delete storage path", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Storage Path\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No StoragePath matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Test Storage Path"].exists)
        XCTAssertTrue(app.staticTexts["0 documents"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit storage path", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Storage Path Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllStoragePaths()
            try await createTestStoragePath()
        }

        continueAfterFailure = false
    }

    private func createTestStoragePath() async throws {
        @Dependency(\.storagePathsRepository)
        var storagePathsRepository

        _ = try await storagePathsRepository.createStoragePath(
            input: .init(
                name: "Test Storage Path",
                path: "/home/paperless/test-storage-path"
            ),
            server: server
        )
    }

    private func deleteAllStoragePaths() async throws {
        @Dependency(\.storagePathsRepository)
        var storagePathsRepository

        let storagePaths = try await storagePathsRepository.getStoragePaths(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for storagePath in storagePaths {
            try await storagePathsRepository.deleteStoragePath(
                id: storagePath,
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
