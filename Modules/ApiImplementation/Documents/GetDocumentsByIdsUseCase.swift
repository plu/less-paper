import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentsByIdsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetDocumentsByIdsUseCase {

    static func execute(
        input: GetDocumentsByIdsInput,
        server: Server
    ) async throws -> [Document] {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getDocumentsByIds(
            input: input,
            server: server
        )
    }
}
