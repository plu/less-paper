@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing

@Suite
struct GetPermissionsUseCaseTests {

    @Test
    func execute() async throws {
        try await withDependencies {
            $0.permissionsRepository.getPermissions = { _, _ in .testValue() }
        } operation: {
            let useCase = GetPermissionsUseCase.liveValue

            let output = try await useCase.execute(
                server: .testValue(),
                type: .tag(id: 17)
            )

            expectNoDifference(output, .testValue())
        }
    }
}
