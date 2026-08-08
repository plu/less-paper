import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension GetStatisticsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetStatisticsUseCase {

    static func execute(
        server: Server
    ) async throws -> GetStatisticsOutput {
        @Shared(.inboxDocumentCount(server))
        var inboxDocumentCount: Int

        @Dependency(\.statisticsRepository)
        var repository

        let statistics = try await repository.getStatistics(
            input: .init(),
            server: server
        )

        $inboxDocumentCount.withLock { $0 = statistics.documentsInbox }

        return statistics
    }
}
