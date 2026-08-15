import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension BulkEditDocumentsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(input:server:)
    )
}

private extension BulkEditDocumentsUseCase {

    static func execute(
        input: BulkEditDocumentsInput,
        server: Server
    ) async throws {
        @Dependency(\.documentsRepository)
        var documentsRepository

        try await documentsRepository.bulkEditDocuments(
            input: input,
            server: server
        )

        await refreshStatistics(server: server)
    }
}
