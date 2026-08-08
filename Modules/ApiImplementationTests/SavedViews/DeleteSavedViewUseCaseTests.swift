@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteSavedViewsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<SavedView.Id?>(nil)
        try await withDependencies {
            $0.savedViewsRepository.deleteSavedView = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteSavedViewUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = [.testValue()]
}
