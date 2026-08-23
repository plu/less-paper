import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DeleteCustomFieldUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteCustomFieldUseCase {

    static func execute(
        id: CustomField.Id,
        server: Server
    ) async throws {
        @Shared(.customFields(server))
        var cache: IdentifiedArrayOf<CustomField> = []

        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        try await customFieldsRepository.deleteCustomField(
            id: id,
            server: server
        )

        _ = $cache.withLock { $0.remove(id: id) }
    }
}
