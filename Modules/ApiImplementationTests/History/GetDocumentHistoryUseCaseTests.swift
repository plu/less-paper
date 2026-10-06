@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct GetDocumentHistoryUseCaseTests {

    @Test
    func execute_forwardsToRepository() async throws {
        let documentIdReceived = LockIsolated<Document.Id?>(nil)
        try await withDependencies {
            $0.historyRepository.getHistory = { documentId, _ in
                documentIdReceived.setValue(documentId)
                return [.testValue()]
            }
        } operation: {
            let entries = try await GetDocumentHistoryUseCase.liveValue.execute(
                9,
                .testValue()
            )

            #expect(documentIdReceived.value == 9)
            #expect(entries == [.testValue()])
        }
    }
}
