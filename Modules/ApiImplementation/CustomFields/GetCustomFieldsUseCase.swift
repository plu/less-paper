import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetCustomFieldsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetCustomFieldsUseCase {

    static func execute(
        server: Server
    ) async throws -> [CustomField] {
        @Shared(.customFields(server))
        var cache: IdentifiedArrayOf<CustomField> = []

        @Dependency(\.customFieldsRepository)
        var repository

        var output = try await repository.getCustomFields(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getCustomFields(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
