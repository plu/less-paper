@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct GetCustomFieldsUseCaseTests {

    @Test
    func execute_followsPaginationAndFillsCache() async throws {
        let secondPage = URL(string: "http://localhost:8000/api/custom_fields/?page=2")

        try await withDependencies {
            $0.customFieldsRepository.getCustomFields = { input, _ in
                if input.url == nil {
                    return .testValue(count: 2, next: secondPage, results: [.testValue(id: 1, name: "Alpha")])
                }
                return .testValue(count: 2, results: [.testValue(id: 2, name: "Beta")])
            }
        } operation: {
            let useCase = GetCustomFieldsUseCase.liveValue

            let customFields = try await useCase.execute(server: .testValue())

            #expect(customFields.map(\.name) == ["Alpha", "Beta"])
        }

        #expect(cache.map(\.id) == [1, 2])
    }

    @Shared(.customFields(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.CustomField> = []
}
