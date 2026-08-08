@testable import ApiImplementation

import ApiInterface
import ApiTestSupport
import Dependencies
import ShareFeature
import XCTest

@MainActor
final class ShareAppTests: XCTestCase {
    func testImport() async throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["With server"].tap()

        app.buttons["Skip"].tap()
        app.secureTextFields["Password"].tap()
        app.typeText("T0PS3CR3T!!123")
        app.buttons["Unlock"].tap()
        app.buttons["Unlock"].waitForNonExistence(timeout: timeout)

        app.buttons["Skip"].tap()
        app.buttons["Correspondent"].tap()
        app.buttons["Add Correspondent"].tap()
        app.typeText("New Correspondent")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        app.buttons["Document type"].tap()
        app.buttons["Add Document type"].tap()
        app.typeText("New Document Type")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        app.buttons["Tags"].tap()
        app.buttons["Add Tags"].tap()
        app.typeText("New Tag")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        app.buttons["Storage path"].tap()
        app.buttons["Add Storage path"].tap()
        app.typeText("New Storage Path")
        app.textFields["Path"].tap()
        app.typeText("/new/storage/path")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)

        app.buttons["Import"].tap()
        app.buttons["Import"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.buttons["With server"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            @Dependency(\.deleteAllCorrespondents.execute)
            var deleteAllCorrespondents

            @Dependency(\.deleteAllDocumentTypes.execute)
            var deleteAllDocumentTypes

            @Dependency(\.deleteAllStoragePaths.execute)
            var deleteAllStoragePaths

            @Dependency(\.deleteAllTags.execute)
            var deleteAllTags

            try await deleteAllCorrespondents(.testValue())
            try await deleteAllDocumentTypes(.testValue())
            try await deleteAllStoragePaths(.testValue())
            try await deleteAllTags(.testValue())
        }

        continueAfterFailure = false
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
