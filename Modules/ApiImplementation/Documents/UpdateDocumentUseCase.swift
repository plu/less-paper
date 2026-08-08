import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension UpdateDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension UpdateDocumentUseCase {

    static func execute(
        id: Document.Id,
        input: UpdateDocumentInput,
        server: Server
    ) async throws -> Document {
        @Dependency(\.documentsRepository)
        var documentsRepository

        @Dependency(\.getStatistics.execute)
        var getStatistics

        let document = try await documentsRepository.updateDocument(
            id: id,
            input: input,
            server: server
        )

        do { _ = try await getStatistics(server) } catch {}

        return document
    }
}
