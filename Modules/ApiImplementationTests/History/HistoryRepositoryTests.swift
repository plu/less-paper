@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct HistoryRepositoryTests {

    // Every consumed document has at least its create entry, so an empty answer means the request
    // or the decoding went wrong, not that there is no history.
    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getHistory_returnsTheCreateEntry() async throws {
        let documents = try await documentsRepository.getDocuments(
            input: .testValue(),
            server: .testValue()
        ).results
        let documentId = try #require(documents.first).id

        let entries = try await repository.getHistory(
            documentId: documentId,
            server: .testValue()
        )

        #expect(entries.contains { $0.action == .create })
    }

    @Dependency(\.historyRepository)
    private var repository

    @Dependency(\.documentsRepository)
    private var documentsRepository
}
