@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveCorrespondentUseCaseTests {

    @Test
    func execute_createCorrespondent() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveCorrespondentInput?>(nil)
        try await withDependencies {
            $0.correspondentsRepository.createCorrespondent = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveCorrespondentUseCase.liveValue

            let correspondents = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(correspondents, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateCorrespondent() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveCorrespondentInput?>(nil)
        try await withDependencies {
            $0.correspondentsRepository.updateCorrespondent = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveCorrespondentUseCase.liveValue

            let correspondents = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(correspondents, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Shared(.correspondents(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.Correspondent> = [.testValue(id: 1)]
}
