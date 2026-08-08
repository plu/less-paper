@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveStoragePathUseCaseTests {

    @Test
    func execute_createStoragePath() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveStoragePathInput?>(nil)
        try await withDependencies {
            $0.storagePathsRepository.createStoragePath = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveStoragePathUseCase.liveValue

            let storagePaths = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(storagePaths, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateStoragePath() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveStoragePathInput?>(nil)
        try await withDependencies {
            $0.storagePathsRepository.updateStoragePath = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveStoragePathUseCase.liveValue

            let storagePaths = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(storagePaths, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Shared(.storagePaths(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.StoragePath> = [.testValue(id: 1)]
}
