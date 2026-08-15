@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct GetStatisticsUseCaseTests {

    @Test
    func execute() async throws {
        try await withDependencies {
            $0.statisticsRepository.getStatistics = { _, _ in
                .testValue()
            }
        } operation: {
            let useCase = GetStatisticsUseCase.liveValue

            let statistics = try await useCase.execute(
                server: .testValue()
            )

            #expect(statistics == .testValue())
        }
    }

    /// The badge count and the Inbox list's filter both come out of this one response, so both
    /// caches have to be written here.
    @Test
    func execute_cachesInboxCountAndTags() async throws {
        @Shared(.inboxDocumentCount(.testValue()))
        var inboxDocumentCount: Int

        @Shared(.inboxTags(.testValue()))
        var inboxTags: [ApiInterface.Tag.Id]

        try await withDependencies {
            $0.statisticsRepository.getStatistics = { _, _ in
                .testValue(
                    documentsInbox: 7,
                    inboxTags: [104, 105]
                )
            }
        } operation: {
            _ = try await GetStatisticsUseCase.liveValue.execute(
                server: .testValue()
            )
        }

        #expect(inboxDocumentCount == 7)
        #expect(inboxTags == [104, 105])
    }
}
