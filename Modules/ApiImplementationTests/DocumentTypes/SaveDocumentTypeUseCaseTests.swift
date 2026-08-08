@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveDocumentTypeUseCaseTests {

    @Test
    func execute_createDocumentType() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveDocumentTypeInput?>(nil)
        try await withDependencies {
            $0.documentTypesRepository.createDocumentType = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveDocumentTypeUseCase.liveValue

            let documenttypes = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(documenttypes, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateDocumentType() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveDocumentTypeInput?>(nil)
        try await withDependencies {
            $0.documentTypesRepository.updateDocumentType = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveDocumentTypeUseCase.liveValue

            let documenttypes = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(documenttypes, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Shared(.documentTypes(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.DocumentType> = [.testValue(id: 1)]
}
