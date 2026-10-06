@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct AuthenticationProviderTests {

    @Test
    func getToken_returnsWhatTheKeychainHolds() async throws {
        let server = Server.testValue()

        let token = try await withDependencies {
            $0.keychain.getCredentials = { receivedServer in
                #expect(receivedServer == server)
                return .testValue(token: "keychain-token")
            }
        } operation: {
            try await AuthenticationProvider.liveValue.getToken(server: server)
        }

        #expect(token == "keychain-token")
    }

    // Remote-user mode stores no token: the proxy injects a trusted identity, so a missing token
    // is a working login rather than a failure.
    @Test
    func getToken_returnsNilWhenTheKeychainHoldsNone() async throws {
        let token = try await withDependencies {
            $0.keychain.getCredentials = { _ in
                .testValue(password: nil, token: nil)
            }
        } operation: {
            try await AuthenticationProvider.liveValue.getToken(server: .testValue())
        }

        #expect(token == nil)
    }
}
