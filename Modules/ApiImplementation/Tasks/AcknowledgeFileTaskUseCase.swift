import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension AcknowledgeFileTaskUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension AcknowledgeFileTaskUseCase {

    static func execute(
        id: FileTask.Id,
        server: Server
    ) async throws {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        let version = apiVersion ?? ApiVersion.minimumSupported

        if version >= 10 {
            try await repository.acknowledgeFileTask(id, server)
        } else {
            try await repository.acknowledgeFileTaskLegacy(id, server)
        }

        // The badge is read from the server so it cannot drift from it: a successful dismiss
        // re-reads the count rather than decrementing it locally, the same way DeleteDocumentsUseCase
        // and CreateDocumentUseCase call refreshStatistics after their own mutations.
        await refreshFailedFileTaskCount(server: server)
    }
}
