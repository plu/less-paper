@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct DeleteStoragePathsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<StoragePath.Id?>(nil)
        try await withDependencies {
            $0.storagePathsRepository.deleteStoragePath = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteStoragePathUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.storagePaths(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.StoragePath> = [.testValue()]
}
