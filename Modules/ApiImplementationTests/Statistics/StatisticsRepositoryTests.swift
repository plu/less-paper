@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct StatisticsRepositoryTests {

    @Test
    func getStatistics_returnsTestValue() async throws {
        let output = try await repository.getStatistics(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getStatistics() async throws {
        let statistics = try await getStatistics()

        #expect(statistics.documentsTotal >= 0)
        #expect(statistics.documentsInbox >= 0)
        #expect(statistics.inboxTags.isEmpty == false || statistics.inboxTags.isEmpty == true)
        #expect(statistics.documentFileTypeCounts.isEmpty == false || statistics.documentFileTypeCounts
            .isEmpty == true)
        #expect(statistics.characterCount >= 0)
        #expect(statistics.tagCount >= 0)
        #expect(statistics.correspondentCount >= 0)
        #expect(statistics.documentTypeCount >= 0)
        #expect(statistics.storagePathCount >= 0)
        #expect(statistics.currentAsn >= 0)

        for fileTypeCount in statistics.documentFileTypeCounts {
            #expect(fileTypeCount.mimeType.isEmpty == false)
            #expect(fileTypeCount.mimeTypeCount >= 0)
        }
    }

    private func getStatistics() async throws -> GetStatisticsOutput {
        let input = GetStatisticsInput()
        return try await repository.getStatistics(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.statisticsRepository)
    private var repository
}
