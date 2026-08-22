@testable import ApiImplementation

import ApiInterface
import Dependencies
import DocumentTypesFeature
import UITestSupport
import XCTest

@MainActor
final class DocumentTypesAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllDocumentTypes()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add document type"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New Document Type")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Document Type"].waitForExistence(timeout: timeout))
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete document type", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Document Type\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllDocumentTypes()
        }

        app.tapSwipeAction("Delete document type", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Document Type\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No DocumentType matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Test Document Type"].exists)
        XCTAssertTrue(app.staticTexts["0 documents"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit document type", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Document Type Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllDocumentTypes()
            try await createTestDocumentType()
        }

        continueAfterFailure = false
    }

    private func createTestDocumentType() async throws {
        @Dependency(\.documentTypesRepository)
        var documentTypesRepository

        _ = try await documentTypesRepository.createDocumentType(
            input: .init(
                name: "Test Document Type"
            ),
            server: server
        )
    }

    private func deleteAllDocumentTypes() async throws {
        @Dependency(\.documentTypesRepository)
        var documentTypesRepository

        let documentTypes = try await documentTypesRepository.getDocumentTypes(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for documentType in documentTypes {
            try await documentTypesRepository.deleteDocumentType(
                id: documentType,
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
