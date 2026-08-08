@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveSavedViewUseCaseTests {

    @Test
    func execute_createSavedView() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        try await withDependencies {
            $0.savedViewsRepository.createSavedView = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveSavedViewUseCase.liveValue

            let savedViews = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(savedViews, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateSavedView() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        try await withDependencies {
            $0.savedViewsRepository.updateSavedView = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveSavedViewUseCase.liveValue

            let savedViews = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(savedViews, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = [.testValue(id: 1)]
}
