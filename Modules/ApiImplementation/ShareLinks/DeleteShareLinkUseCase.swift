import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension DeleteShareLinkUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension DeleteShareLinkUseCase {

    static func execute(
        id: ShareLink.Id,
        server: Server
    ) async throws {
        @Dependency(\.shareLinksRepository)
        var repository

        try await repository.deleteShareLink(
            id: id,
            server: server
        )
    }
}
