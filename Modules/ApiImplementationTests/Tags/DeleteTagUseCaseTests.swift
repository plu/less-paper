@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteTagsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<ApiInterface.Tag.Id?>(nil)
        try await withDependencies {
            $0.tagsRepository.deleteTag = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteTagUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.tags(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.Tag> = [.testValue()]
}
