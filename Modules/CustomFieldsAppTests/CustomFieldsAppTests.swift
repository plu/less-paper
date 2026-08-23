@testable import ApiImplementation

import ApiInterface
import CustomFieldsFeature
import Dependencies
import UITestSupport
import XCTest

@MainActor
final class CustomFieldsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        let app = XCUIApplication()
        app.launch()

        // The app renders a ProgressView until `updateCache` resolves, so the button does not
        // exist at launch. Tapping straight away races that fetch.
        let addButton = app.buttons["Add custom field"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()
        app.textFields["Name"].tap()
        app.typeText("New Custom Field")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Custom Field"].waitForExistence(timeout: timeout))
    }

    func testCreateSelect() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        let app = XCUIApplication()
        app.launch()

        let addButton = app.buttons["Add custom field"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()
        app.textFields["Name"].tap()
        app.typeText("Status")

        // A SwiftUI menu Picker is exposed as a button labelled with its *current* value, not with
        // the field title — "Data type" is only the Field's caption, and matches no button.
        let dataTypeButton = app.buttons["Text"].firstMatch
        XCTAssertTrue(dataTypeButton.waitForExistence(timeout: timeout))
        dataTypeButton.tap()
        app.buttons["Select"].firstMatch.tap()

        let addOptionButton = app.buttons["Add option"].firstMatch
        XCTAssertTrue(addOptionButton.waitForExistence(timeout: timeout))
        addOptionButton.tap()

        // Deliberately no tap on the new row: it takes focus when it appears, so typing straight
        // away has to land in it. A tap here would hide a regression in that focus hand-off.
        XCTAssertTrue(app.textFields["Option"].firstMatch.waitForExistence(timeout: timeout))
        app.typeText("Open")
        XCTAssertEqual(app.textFields["Option"].firstMatch.value as? String, "Open")

        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: timeout))

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.textFields["Option"].firstMatch.waitForExistence(timeout: timeout))
        XCTAssertEqual(app.textFields["Option"].firstMatch.value as? String, "Open")
    }

    // Deleting a blank option used to crash with "Index out of range": the rows were built from
    // `ForEach($binding)`, whose element bindings are index-based, and the removed row's field
    // wrote back into its stale index as it disappeared.
    func testDeleteBlankOption() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
            try await createTestSelectCustomField()
        }

        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)

        let addOptionButton = app.buttons["Add option"].firstMatch
        XCTAssertTrue(addOptionButton.waitForExistence(timeout: timeout))
        addOptionButton.tap()
        addOptionButton.tap()

        let deleteOptionButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Delete option"))
        XCTAssertEqual(deleteOptionButtons.count, 3)

        deleteOptionButtons.element(boundBy: 2).tap()

        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Delete option")).count, 2)
        XCTAssertTrue(app.buttons["Save"].firstMatch.waitForExistence(timeout: timeout))
        XCTAssertEqual(app.textFields.matching(NSPredicate(format: "value == %@", "Open")).count, 1)
    }

    // Cancelling with a blank option used to send `optionLabelChanged` from the field's teardown,
    // after the parent had already cleared the destination — TCA warns about a presentation action
    // arriving with no state. The warning is only visible in the log, so this test walks the path
    // and `testNoPresentationWarningOnCancel` in the log capture asserts it stays quiet.
    func testCancelWithBlankOption() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
            try await createTestSelectCustomField()
        }

        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)

        let addOptionButton = app.buttons["Add option"].firstMatch
        XCTAssertTrue(addOptionButton.waitForExistence(timeout: timeout))
        addOptionButton.tap()

        app.buttons["Cancel"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Test Select Field"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Add custom field"].firstMatch.waitForExistence(timeout: timeout))
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Custom Field\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        app.tapSwipeAction("Delete custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Custom Field\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No CustomField matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Test Custom Field"].exists)
        XCTAssertTrue(app.staticTexts["Text · 0 documents"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Custom Field Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllCustomFields()
            try await createTestCustomField()
        }

        continueAfterFailure = false
    }

    private func createTestCustomField() async throws {
        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        _ = try await customFieldsRepository.createCustomField(
            input: .init(
                dataType: .string,
                name: "Test Custom Field"
            ),
            server: server
        )
    }

    private func createTestSelectCustomField() async throws {
        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        _ = try await customFieldsRepository.createCustomField(
            input: .init(
                dataType: .select,
                extraData: .init(selectOptions: [.init(label: "Open")]),
                name: "Test Select Field"
            ),
            server: server
        )
    }

    private func deleteAllCustomFields() async throws {
        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        let customFields = try await customFieldsRepository.getCustomFields(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for customField in customFields {
            try await customFieldsRepository.deleteCustomField(
                id: customField,
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
