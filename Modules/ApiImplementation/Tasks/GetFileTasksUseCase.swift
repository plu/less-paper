import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension GetFileTasksUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:status:page:)
    )
}

private extension GetFileTasksUseCase {

    static func execute(
        server: Server,
        status: FileTaskStatus,
        page: Int
    ) async throws -> FileTaskPage {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        // Not yet negotiated reads as the oldest server this app supports, the same rule
        // GetSavedViewsUseCase follows: the newer shape is earned by a version we have seen.
        let version = apiVersion ?? ApiVersion.minimumSupported

        guard version >= 10 else {
            let payloads = try await repository.getFileTasksV9(server)
            // Dismissed rows are dropped on every segment, matching the acknowledged=false the v10
            // query sends and the count query on both versions. A row the user swiped away has to
            // stay away - otherwise a refresh brings it back while the badge still says it is gone.
            let tasks = payloads
                .filter(\.isConsumeFile)
                .map(\.asFileTask)
                .filter { $0.status == status && !$0.isAcknowledged }
                .sorted { $0.dateCreated > $1.dateCreated }

            // An unpaginated endpoint has already handed over everything it has.
            return FileTaskPage(nextPage: nil, tasks: tasks)
        }

        let output = try await repository.getFileTasksV10(status, page, server)

        return FileTaskPage(
            nextPage: output.next == nil ? nil : page + 1,
            tasks: output.results.map(\.asFileTask)
        )
    }
}
