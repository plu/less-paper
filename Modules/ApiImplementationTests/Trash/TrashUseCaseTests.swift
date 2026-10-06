@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct TrashUseCaseTests {

    @Test
    func getTrash_forwardsToRepository() async throws {
        try await withDependencies {
            $0.trashRepository.getTrash = { _ in .testValue() }
        } operation: {
            let output = try await GetTrashUseCase.liveValue.execute(
                .testValue()
            )

            #expect(output == .testValue())
        }
    }

    @Test
    func emptyTrash_forwardsToRepository() async throws {
        let received = LockIsolated<[Document.Id]?>(nil)
        try await withDependencies {
            $0.trashRepository.emptyTrash = { ids, _ in
                received.setValue(ids)
            }
        } operation: {
            try await EmptyTrashUseCase.liveValue.execute(
                [1, 2],
                .testValue()
            )

            #expect(received.value == [1, 2])
        }
    }

    @Test
    func restoreDocuments_restoresAndRefreshesTheCache() async throws {
        let received = LockIsolated<[Document.Id]?>(nil)
        let cacheRefreshed = LockIsolated(false)
        try await withDependencies {
            $0.trashRepository.restoreDocuments = { ids, _ in
                received.setValue(ids)
            }
            $0.updateCache.execute = { _ in
                cacheRefreshed.setValue(true)
            }
        } operation: {
            try await RestoreDocumentsUseCase.liveValue.execute(
                [1, 3],
                .testValue()
            )

            #expect(received.value == [1, 3])
        }

        #expect(cacheRefreshed.value == true)
    }
}
