@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct CustomFieldsRepositoryTests {

    @Test
    func createCustomField_returnsTestValue() async throws {
        let output = try await repository.createCustomField(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteCustomField_returnsVoid() async throws {
        try await repository.deleteCustomField(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getCustomFields_returnsTestValue() async throws {
        let output = try await repository.getCustomFields(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateCustomField_returnsTestValue() async throws {
        let output = try await repository.updateCustomField(
            id: 1,
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud() async throws {
        var customField = try await createCustomField()
        #expect(customField.dataType == .string)
        #expect(customField.documentCount == 0)
        #expect(customField.id > 0)
        #expect(customField.name == "Test CustomField")

        var customFields = try await getCustomFields()
        #expect(customFields.results.map(\.id) == [customField.id])
        #expect(customFields.count == 1)
        #expect(customFields.next == nil)

        var updateInput = SaveCustomFieldInput(customField: customField)
        updateInput.name = "Updated Name"
        customField = try await repository.updateCustomField(
            id: customField.id,
            input: updateInput,
            server: .testValue()
        )
        #expect(customField.name == "Updated Name")
        #expect(customField.dataType == .string)

        try await deleteCustomField(customField.id)
        customFields = try await getCustomFields()
        #expect(customFields.results == [])
        #expect(customFields.next == nil)
    }

    // The server assigns each select option an opaque string id on create. Nothing else in the app
    // generates those, so this pins the behaviour the form depends on.
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud_select_serverAssignsOptionIds() async throws {
        let customField = try await repository.createCustomField(
            input: .init(
                dataType: .select,
                extraData: .init(selectOptions: [.init(label: "Open"), .init(label: "Closed")]),
                name: "Status"
            ),
            server: .testValue()
        )

        let options = try #require(customField.extraData?.selectOptions)
        #expect(options.map(\.label) == ["Open", "Closed"])
        #expect(options.allSatisfy { $0.id?.isEmpty == false })

        try await deleteCustomField(customField.id)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud_monetary_roundTripsDefaultCurrency() async throws {
        let customField = try await repository.createCustomField(
            input: .init(
                dataType: .monetary,
                extraData: .init(defaultCurrency: "EUR"),
                name: "Invoice total"
            ),
            server: .testValue()
        )

        #expect(customField.extraData?.defaultCurrency == "EUR")

        try await deleteCustomField(customField.id)
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createCustomField() async throws -> SaveCustomFieldOutput {
        let input = SaveCustomFieldInput(
            dataType: .string,
            name: "Test CustomField"
        )
        return try await repository.createCustomField(
            input: input,
            server: .testValue()
        )
    }

    private func deleteCustomField(_ id: CustomField.Id) async throws -> DeleteCustomFieldOutput {
        try await repository.deleteCustomField(
            id: id,
            server: .testValue()
        )
    }

    private func getCustomFields() async throws -> GetCustomFieldsOutput {
        let input = GetCustomFieldsInput()
        return try await repository.getCustomFields(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.customFieldsRepository)
    private var repository
}
