import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension CreateDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension CreateDocumentUseCase {

    static func execute(
        input: CreateDocumentInput,
        server: Server
    ) async throws {
        @Dependency(\.documentsRepository)
        var documentsRepository

        return try await documentsRepository.createDocument(
            input: input,
            server: server
        )
    }
}
