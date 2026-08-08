@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveTagUseCaseTests {

    @Test
    func execute_createTag() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveTagInput?>(nil)
        try await withDependencies {
            $0.tagsRepository.createTag = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveTagUseCase.liveValue

            let tag = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(tag, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateTag() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveTagInput?>(nil)
        try await withDependencies {
            $0.tagsRepository.updateTag = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveTagUseCase.liveValue

            let tag = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(tag, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Shared(.tags(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.Tag> = [.testValue(id: 1)]
}
