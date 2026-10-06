@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DeleteCustomFieldUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [.testValue()])

        let inputReceived = LockIsolated<CustomField.Id?>(nil)
        try await withDependencies {
            $0.customFieldsRepository.deleteCustomField = { id, _ in
                inputReceived.setValue(id)
            }
        } operation: {
            let useCase = DeleteCustomFieldUseCase.liveValue

            try await useCase.execute(
                id: 1,
                server: .testValue()
            )

            #expect(inputReceived.value == 1)
        }

        #expect(cache == [])
    }

    @Shared(.customFields(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.CustomField> = [.testValue()]
}
