@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct UITestBootstrapTests {

    @Test
    func seedsSelectedServerFromConfiguration() async throws {
        let configuration = UITestConfiguration.testValue()

        withDependencies {
            $0.applyUITestConfiguration(configuration)
        } operation: {
            seedUITestSharedState(configuration)

            @Shared(.selectedServer)
            var selectedServer

            @Shared(.servers)
            var servers

            expectNoDifference(selectedServer, configuration.seed?.server)
            expectNoDifference(Array(servers), [Server.testValue()])
        }
    }

    @Test
    func leavesServersEmptyWithoutASeed() async throws {
        let configuration = UITestConfiguration()

        withDependencies {
            $0.applyUITestConfiguration(configuration)
        } operation: {
            seedUITestSharedState(configuration)

            @Shared(.selectedServer)
            var selectedServer

            @Shared(.servers)
            var servers

            #expect(selectedServer == nil)
            #expect(servers.isEmpty)
        }
    }

    @Test
    func seedsKeychainFromConfiguration() async throws {
        let configuration = UITestConfiguration.testValue()

        try await withDependencies {
            $0.applyUITestConfiguration(configuration)
        } operation: {
            @Dependency(\.keychain)
            var keychain

            let credentials = try await keychain.getCredentials(server: .testValue())

            expectNoDifference(
                credentials,
                Credentials(password: "secret", token: "abc123")
            )
        }
    }

    @Test
    func storesCredentialsWrittenByTheApp() async throws {
        try await withDependencies {
            $0.applyUITestConfiguration(UITestConfiguration())
        } operation: {
            @Dependency(\.keychain)
            var keychain

            await #expect(throws: (any Error).self) {
                try await keychain.getCredentials(server: .testValue())
            }

            let written = Credentials(password: "typed", token: "issued")
            try await keychain.storeCredentials(written, .testValue())

            let read = try await keychain.getCredentials(server: .testValue())
            expectNoDifference(read, written)
        }
    }

    @Test
    func storesPdfPasswordsInMemory() async throws {
        try await withDependencies {
            $0.applyUITestConfiguration(UITestConfiguration.testValue())
        } operation: {
            @Dependency(\.keychain)
            var keychain

            let initial = try await keychain.getPdfPasswords()
            expectNoDifference(initial, [])

            try await keychain.setPdfPasswords([.testValue()])

            let stored = try await keychain.getPdfPasswords()
            expectNoDifference(stored, [.testValue()])
        }
    }
}

private extension UITestConfiguration {

    static func testValue() -> Self {
        .init(
            seed: .init(
                password: "secret",
                server: .testValue(),
                token: "abc123"
            )
        )
    }
}
