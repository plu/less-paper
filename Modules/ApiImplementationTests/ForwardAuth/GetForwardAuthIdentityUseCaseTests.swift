@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetForwardAuthIdentityUseCaseTests {

    // A 200 without an Authorization header means the proxy is injecting Remote-User; the app
    // stores a server with no token and shows that username.
    @Test
    func remoteUser_returnsTheUsername() async throws {
        let username = try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                UISettings.testValue(user: .testValue(id: 42))
            }
            $0.usersRepository.getUser = { input, _ in
                #expect(input.id == 42)
                return User.testValue(id: 42, username: "authelia-user")
            }
        } operation: {
            try await GetForwardAuthIdentityUseCase.liveValue.execute(server: .testValue())
        }

        #expect(username == "authelia-user")
    }

    // 401 from paperless behind a gate-only proxy means the cookie got past the proxy but
    // paperless still needs a token. Return nil so the caller runs the ordinary login.
    @Test
    func gateOnly_returnsNil() async throws {
        let username = try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                throw ApiError.testValue(errors: ["Authentication credentials were not provided."])
            }
        } operation: {
            try await GetForwardAuthIdentityUseCase.liveValue.execute(server: .testValue())
        }

        #expect(username == nil)
    }

    // Anything that is not an ApiError - the server being off, a certificate mismatch, a 5xx -
    // is a real problem, not "gate-only". It has to propagate rather than silently downgrade.
    @Test
    func networkFailure_isRethrown() async throws {
        await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                throw URLError(.cannotConnectToHost)
            }
        } operation: {
            await #expect(throws: URLError.self) {
                try await GetForwardAuthIdentityUseCase.liveValue.execute(server: .testValue())
            }
        }
    }
}
