import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllCustomFieldsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllCustomFieldsUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getCustomFields.execute)
        var getCustomFields

        @Dependency(\.deleteCustomField.execute)
        var deleteCustomField

        let customFields = try await getCustomFields(server)

        for customField in customFields {
            try await deleteCustomField(customField.id, server)
        }
    }
}
