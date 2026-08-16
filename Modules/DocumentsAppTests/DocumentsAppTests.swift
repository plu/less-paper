@testable import ApiImplementation

import ApiInterface
import Dependencies
import XCTest

@MainActor
final class DocumentsAppTests: XCTestCase {
    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        app.buttons["Filter"].firstMatch.tap()
        app.textFields["Title & content"].firstMatch.tap()
        app.textFields["Title & content"].firstMatch.typeText("Lego")
        app.buttons["Close"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Lego Duplo"].exists)
        XCTAssertTrue(app.staticTexts["Lego Friends"].exists)
        XCTAssertTrue(app.staticTexts["2 of 2 loaded"].exists)
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
