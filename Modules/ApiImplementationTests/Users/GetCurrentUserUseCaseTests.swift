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
        } operation: {
            let useCase = GetCurrentUserUseCase.liveValue

            let user = try await useCase.execute(
                server: .testValue()
            )

            #expect(user == .testValue())
        }

        #expect(cache == .testValue())
    }

    @Test
    func cachesTheUserAndPermissionsFromUISettings() async throws {
        let server = Server.testValue()

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .testValue(
                    user: .testValue(id: 40, isSuperuser: false, username: "permtest"),
                    permissions: [.viewDocument, .changeDocument]
                )
            }
        } operation: {
            let user = try await GetCurrentUserUseCase.liveValue.execute(server)

            #expect(user.username == "permtest")

            @Shared(.currentUser(server))
            var cachedUser: User?

            @Shared(.permissions(server))
            var permissions: [Permission]?

            #expect(cachedUser?.id == 40)
            #expect(permissions == [.viewDocument, .changeDocument])
        }
    }

    @Shared(.currentUser(.testValue()))
    private var cache: User?
}
