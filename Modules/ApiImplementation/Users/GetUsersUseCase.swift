import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetUsersUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetUsersUseCase {

    static func execute(
        server: Server
    ) async throws -> [User] {
        @Shared(.users(server))
        var cache: IdentifiedArrayOf<User> = []

        @Dependency(\.usersRepository)
        var repository

        var output = try await repository.getUsers(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getUsers(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
