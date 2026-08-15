@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteDocumentsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache.ids.elements == [1, 2, 3])

        let inputReceived = LockIsolated<BulkEditDocumentsInput?>(nil)
        try await withDependencies {
            $0.documentsRepository.bulkEditDocuments = { input, _ in
                inputReceived.setValue(input)
            }
        } operation: {
            let useCase = DeleteDocumentsUseCase.liveValue

            try await useCase.execute(
                ids: [1, 3],
                server: .testValue()
            )

            #expect(inputReceived.value == BulkEditDocumentsInput(
                documents: [1, 3],
                method: .delete
            ))
        }

        #expect(cache.ids.elements == [2])
    }

    @Shared(.documents(.testValue()))
    private var cache: IdentifiedArrayOf<Document> = .init(uniqueElements: [
        .testValue(id: 1),
        .testValue(id: 2),
        .testValue(id: 3),
    ])
}
