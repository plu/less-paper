@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteCorrespondentsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<Correspondent.Id?>(nil)
        try await withDependencies {
            $0.correspondentsRepository.deleteCorrespondent = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteCorrespondentUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.correspondents(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.Correspondent> = [.testValue()]
}
