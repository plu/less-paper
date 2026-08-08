import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetGroupsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetGroupsUseCase {

    static func execute(
        server: Server
    ) async throws -> [Group] {
        @Shared(.groups(server))
        var cache: IdentifiedArrayOf<Group> = []

        @Dependency(\.groupsRepository)
        var repository

        var output = try await repository.getGroups(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getGroups(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
