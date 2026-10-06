@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct StoreProviderTokenUseCaseTests {

    @Test
    func execute_storesTheTokenWithoutAPassword() async throws {
        let server = Server.testValue()
        let stored = LockIsolated<Credentials?>(nil)

        try await withDependencies {
            $0.keychain.storeCredentials = { credentials, _ in
                stored.setValue(credentials)
            }
        } operation: {
            try await StoreProviderTokenUseCase.liveValue.execute(
                server,
                "provider-token"
            )
        }

        #expect(stored.value?.password == nil)
        #expect(stored.value?.token == "provider-token")
    }

    @Test
    func execute_propagatesAKeychainFailure() async throws {
        struct StorageFailed: Error {}

        await #expect(throws: StorageFailed.self) {
            try await withDependencies {
                $0.keychain.storeCredentials = { _, _ in
                    throw StorageFailed()
                }
            } operation: {
                try await StoreProviderTokenUseCase.liveValue.execute(
                    .testValue(),
                    "provider-token"
                )
            }
        }
    }
}

@Suite(
    .testDependencies()
)
struct StoreServerWithoutTokenUseCaseTests {

    @Test
    func execute_storesNeitherPasswordNorToken() async throws {
        let stored = LockIsolated<Credentials?>(nil)

        try await withDependencies {
            $0.keychain.storeCredentials = { credentials, _ in
                stored.setValue(credentials)
            }
        } operation: {
            try await StoreServerWithoutTokenUseCase.liveValue.execute(
                .testValue()
            )
        }

        #expect(stored.value?.password == nil)
        #expect(stored.value?.token == nil)
    }

    @Test
    func execute_propagatesAKeychainFailure() async throws {
        struct StorageFailed: Error {}

        await #expect(throws: StorageFailed.self) {
            try await withDependencies {
                $0.keychain.storeCredentials = { _, _ in
                    throw StorageFailed()
                }
            } operation: {
                try await StoreServerWithoutTokenUseCase.liveValue.execute(
                    .testValue()
                )
            }
        }
    }
}
