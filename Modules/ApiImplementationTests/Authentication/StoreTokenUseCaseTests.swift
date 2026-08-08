import ApiInterface
import Dependencies
import Testing

@testable import ApiImplementation

@Suite
struct StoreTokenUseCaseTests {

    @Test
    func executeGetsTokenAndStoresCredentials() async throws {
        let password = "test-password"
        let server = Server.testValue()
        let username = "test-user"
        let expectedToken = "test-token-123"

        let repositoryCalled = LockIsolated(false)
        let keychainCalled = LockIsolated(false)
        let storedCredentials = LockIsolated<Credentials?>(nil)

        try await withDependencies {
            $0.authenticationRepository.getToken = { input, receivedServer in
                repositoryCalled.setValue(true)
                #expect(input.password == password)
                #expect(input.username == username)
                #expect(receivedServer == server)
                return .testValue(token: expectedToken)
            }
            $0.keychain.storeCredentials = { credentials, receivedServer in
                keychainCalled.setValue(true)
                storedCredentials.setValue(credentials)
                #expect(receivedServer == server)
            }
        } operation: {
            try await StoreTokenUseCase.liveValue.execute(
                code: nil,
                password: password,
                server: server,
                username: username
            )
        }

        #expect(repositoryCalled.value == true)
        #expect(keychainCalled.value == true)
        #expect(storedCredentials.value?.password == password)
        #expect(storedCredentials.value?.token == expectedToken)
    }

    @Test
    func executeThrowsErrorWhenRepositoryFails() async throws {
        let password = "test-password"
        let server = Server.testValue()
        let username = "test-user"
        let expectedError = TestError.repositoryError

        await #expect(throws: TestError.self) {
            try await withDependencies {
                $0.authenticationRepository.getToken = { _, _ in
                    throw expectedError
                }
                $0.keychain.storeCredentials = { _, _ in
                    Issue.record("Keychain should not be called when repository fails")
                }
            } operation: {
                try await StoreTokenUseCase.liveValue.execute(
                    code: nil,
                    password: password,
                    server: server,
                    username: username
                )
            }
        }
    }

    @Test
    func executeThrowsErrorWhenKeychainFails() async throws {
        let password = "test-password"
        let server = Server.testValue()
        let username = "test-user"
        let expectedError = TestError.keychainError

        await #expect(throws: TestError.self) {
            try await withDependencies {
                $0.authenticationRepository.getToken = { _, _ in
                    .testValue(token: "test-token")
                }
                $0.keychain.storeCredentials = { _, _ in
                    throw expectedError
                }
            } operation: {
                try await StoreTokenUseCase.liveValue.execute(
                    code: nil,
                    password: password,
                    server: server,
                    username: username
                )
            }
        }
    }

    @Test
    func executeCreatesCorrectGetTokenInput() async throws {
        let password = "special-password-123"
        let server = Server.testValue()
        let username = "special-user-456"
        let receivedInput = LockIsolated<GetTokenInput?>(nil)

        try await withDependencies {
            $0.authenticationRepository.getToken = { input, _ in
                receivedInput.setValue(input)
                return .testValue()
            }
            $0.keychain.storeCredentials = { _, _ in }
        } operation: {
            try await StoreTokenUseCase.liveValue.execute(
                code: nil,
                password: password,
                server: server,
                username: username
            )
        }

        #expect(receivedInput.value?.password == password)
        #expect(receivedInput.value?.username == username)
    }

    @Test
    func executeCreatesCorrectCredentials() async throws {
        let password = "my-password"
        let server = Server.testValue()
        let username = "my-user"
        let token = "my-token-xyz"
        let storedCredentials = LockIsolated<Credentials?>(nil)

        try await withDependencies {
            $0.authenticationRepository.getToken = { _, _ in
                .testValue(token: token)
            }
            $0.keychain.storeCredentials = { credentials, _ in
                storedCredentials.setValue(credentials)
            }
        } operation: {
            try await StoreTokenUseCase.liveValue.execute(
                code: nil,
                password: password,
                server: server,
                username: username
            )
        }

        #expect(storedCredentials.value?.password == password)
        #expect(storedCredentials.value?.token == token)
    }
}

private enum TestError: Error, Equatable {
    case repositoryError
    case keychainError
}
