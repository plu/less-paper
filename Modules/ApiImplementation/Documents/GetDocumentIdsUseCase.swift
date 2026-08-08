import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetAllDocumentIdsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetAllDocumentIdsUseCase {
    static func execute(
        input: GetAllDocumentIdsInput,
        server: Server
    ) async throws -> GetAllDocumentIdsOutput {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getAllDocumentIds(
            input: input,
            server: server
        )
    }
}
