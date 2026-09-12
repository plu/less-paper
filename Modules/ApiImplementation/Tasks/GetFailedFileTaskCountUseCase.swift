import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension GetFailedFileTaskCountUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetFailedFileTaskCountUseCase {

    static func execute(server: Server) async throws -> Int {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int

        // Not yet negotiated reads as the oldest server this app supports, the same rule
        // GetFileTasksUseCase follows.
        let version = apiVersion ?? ApiVersion.minimumSupported
        let count: Int

        if version >= 10 {
            // status_counts/ exists here and would be one smaller request, but its `needs_attention`
            // is not documented as "unacknowledged failures" and does not exist on v9 at all. `count`
            // off a one-row page answers exactly the question being asked.
            count = try await repository.getFailedFileTaskCountV10(server)
        } else {
            count = try await repository.getFileTasksV9(server)
                .filter(\.isConsumeFile)
                .map(\.asFileTask)
                .filter { $0.status == .failed && !$0.isAcknowledged }
                .count
        }

        // Written here rather than by the callers, exactly as GetStatisticsUseCase writes
        // inboxDocumentCount: every caller then just runs the use case and discards the result, and
        // no feature reducer has to touch a @Shared key.
        $failedFileTaskCount.withLock { $0 = count }

        return count
    }
}
