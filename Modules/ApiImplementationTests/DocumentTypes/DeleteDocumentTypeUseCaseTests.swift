@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteDocumentTypesUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<DocumentType.Id?>(nil)
        try await withDependencies {
            $0.documentTypesRepository.deleteDocumentType = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteDocumentTypeUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.documentTypes(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.DocumentType> = [.testValue()]
}
