@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SaveCustomFieldUseCaseTests {

    @Test
    func execute_createCustomField() async throws {
        let inputReceived = LockIsolated<SaveCustomFieldInput?>(nil)
        try await withDependencies {
            $0.customFieldsRepository.createCustomField = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 7, name: "Created")
            }
        } operation: {
            let useCase = SaveCustomFieldUseCase.liveValue

            let customField = try await useCase.execute(
                id: nil,
                input: .testValue(name: "Created"),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue(name: "Created"))
            expectNoDifference(customField, .testValue(id: 7, name: "Created"))
        }

        #expect(cache.map(\.id) == [7])
    }

    // The cache is kept in the same name order the list screen renders in, so a rename that moves a
    // field does not leave the cache disagreeing with the list.
    @Test
    func execute_updateCustomField_sortsCacheByName() async throws {
        $cache.withLock { $0 = .init(uniqueElements: [.testValue(id: 1, name: "Zulu")]) }

        let idReceived = LockIsolated<CustomField.Id?>(nil)
        try await withDependencies {
            $0.customFieldsRepository.updateCustomField = { id, _, _ in
                idReceived.setValue(id)
                return .testValue(id: 2, name: "Alpha")
            }
        } operation: {
            let useCase = SaveCustomFieldUseCase.liveValue

            _ = try await useCase.execute(
                id: 2,
                input: .testValue(name: "Alpha"),
                server: .testValue()
            )
        }

        #expect(idReceived.value == 2)
        #expect(cache.map(\.name) == ["Alpha", "Zulu"])
    }

    @Shared(.customFields(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.CustomField> = []
}
