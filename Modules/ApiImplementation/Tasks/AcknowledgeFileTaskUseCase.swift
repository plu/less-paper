import ApiInterface
import Dependencies
import Foundation

extension AcknowledgeFileTaskUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension AcknowledgeFileTaskUseCase {

    // No version branch: measured against live servers, `/api/acknowledge_tasks/` (the legacy path
    // this used to fall back to below API 10) answers 403 on both 2.15.3 (API 8) and 2.19.6 (API 9)
    // — the entire supported range below 10 — and only works on API 3, which
    // `ApiVersion.negotiated(from:)` rejects outright. `/api/tasks/acknowledge/` is the only path
    // that has ever worked on a server this app supports, so it is the only one called.
    static func execute(
        id: FileTask.Id,
        server: Server
    ) async throws {
        @Dependency(\.fileTaskRepository)
        var repository

        try await repository.acknowledgeFileTask(id, server)

        // The badge is read from the server so it cannot drift from it: a successful dismiss
        // re-reads the count rather than decrementing it locally, the same way DeleteDocumentsUseCase
        // and CreateDocumentUseCase call refreshStatistics after their own mutations.
        await refreshFailedFileTaskCount(server: server)
    }
}
