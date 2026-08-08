import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetPermissionsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:type:)
    )
}

private extension GetPermissionsUseCase {

    static func execute(
        server: Server,
        type: PermissionsType?
    ) async throws -> GetPermissionsOutput {
        guard let type else {
            return .init()
        }

        @Dependency(\.permissionsRepository)
        var repository

        let output = try await repository.getPermissions(
            input: .init(type: type),
            server: server
        )

        return output
    }
}
