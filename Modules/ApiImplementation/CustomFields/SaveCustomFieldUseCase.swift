import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveCustomFieldUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveCustomFieldUseCase {

    static func execute(
        id: CustomField.Id?,
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        @Shared(.customFields(server))
        var cache: IdentifiedArrayOf<CustomField> = []

        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        let result: SaveCustomFieldOutput

        if let id {
            result = try await customFieldsRepository.updateCustomField(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await customFieldsRepository.createCustomField(
                input: input,
                server: server
            )
        }

        $cache.withLock { cache in
            cache.updateOrAppend(result)
            cache.sort {
                $0.name.compare(
                    $1.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
        }

        return result
    }
}
