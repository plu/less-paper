import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetDocumentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension GetDocumentsUseCase {

    static func execute(
        input: GetDocumentsInput,
        server: Server
    ) async throws -> GetDocumentsOutput {
        @Dependency(\.documentsRepository)
        var repository

        return try await repository.getDocuments(
            input: input,
            server: server
        )
    }
}
