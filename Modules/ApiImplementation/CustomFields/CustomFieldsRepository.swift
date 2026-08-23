import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct CustomFieldsRepository: Sendable {

    var createCustomField: @Sendable (
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput

    var deleteCustomField: @Sendable (
        _ id: CustomField.Id,
        _ server: Server
    ) async throws -> DeleteCustomFieldOutput

    var getCustomFields: @Sendable (
        _ input: GetCustomFieldsInput,
        _ server: Server
    ) async throws -> GetCustomFieldsOutput

    var updateCustomField: @Sendable (
        _ id: CustomField.Id,
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput
}

extension CustomFieldsRepository: TestDependencyKey {

    static let previewValue = Self(
        createCustomField: { _, _ in .testValue() },
        deleteCustomField: { _, _ in },
        getCustomFields: { _, _ in .testValue(results: .previewValue) },
        updateCustomField: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createCustomField: { _, _ in .testValue() },
        deleteCustomField: { _, _ in },
        getCustomFields: { _, _ in .testValue() },
        updateCustomField: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var customFieldsRepository: CustomFieldsRepository {
        get { self[CustomFieldsRepository.self] }
        set { self[CustomFieldsRepository.self] = newValue }
    }
}

extension CustomFieldsRepository: DependencyKey {
    static let liveValue = Self(
        createCustomField: createCustomField(input:server:),
        deleteCustomField: deleteCustomField(id:server:),
        getCustomFields: getCustomFields(input:server:),
        updateCustomField: updateCustomField(id:input:server:)
    )
}

private extension CustomFieldsRepository {

    static func createCustomField(
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteCustomField(
        id: CustomField.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getCustomFields(
        input: GetCustomFieldsInput,
        server: Server
    ) async throws -> GetCustomFieldsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateCustomField(
        id: CustomField.Id,
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetCustomFieldsOutput {

    init(input: GetCustomFieldsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/custom_fields/",
            method: .get
        )
    }
}
