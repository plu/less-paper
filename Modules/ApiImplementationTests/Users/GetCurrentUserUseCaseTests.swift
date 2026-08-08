@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct GetCurrentUserUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == nil)

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in .testValue() }
            $0.usersRepository.getUser = { _, _ in .testValue() }
        } operation: {
            let useCase = GetCurrentUserUseCase.liveValue

            let user = try await useCase.execute(
                server: .testValue()
            )

            #expect(user == .testValue())
        }

        #expect(cache == .testValue())
    }

    @Shared(.currentUser(.testValue()))
    private var cache: User?
}
