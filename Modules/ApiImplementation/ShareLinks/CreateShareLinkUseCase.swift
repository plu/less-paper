import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension CreateShareLinkUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension CreateShareLinkUseCase {

    static func execute(
        input: CreateShareLinkInput,
        server: Server
    ) async throws -> ShareLink {
        @Dependency(\.shareLinksRepository)
        var repository

        return try await repository.createShareLink(
            input: input,
            server: server
        )
    }
}
