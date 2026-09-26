import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentHistoryUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:server:)
    )
}

private extension GetDocumentHistoryUseCase {

    static func execute(
        documentId: Document.Id,
        server: Server
    ) async throws -> [AuditLogEntry] {
        @Dependency(\.historyRepository)
        var repository

        return try await repository.getHistory(
            documentId: documentId,
            server: server
        )
    }
}
