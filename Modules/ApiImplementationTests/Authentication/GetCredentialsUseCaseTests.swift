import ApiInterface
import Dependencies
import Testing

@testable import ApiImplementation

@Suite
struct GetCredentialsUseCaseTests {

    @Test
    func executeReturnsCredentialsFromKeychain() async throws {
        let server = Server.testValue()
        let expectedCredentials = Credentials.testValue()
        let keychainCalled = LockIsolated(false)

        let result = try await withDependencies {
            $0.keychain.getCredentials = { receivedServer in
                keychainCalled.setValue(true)
                #expect(receivedServer == server)
                return expectedCredentials
            }
        } operation: {
            try await GetCredentialsUseCase.liveValue.execute(server)
        }

        #expect(keychainCalled.value == true)
        #expect(result == expectedCredentials)
    }

    @Test
    func executeThrowsErrorWhenKeychainFails() async throws {
        let server = Server.testValue()
        let expectedError = TestError.keychainError

        await #expect(throws: TestError.self) {
            try await withDependencies {
                $0.keychain.getCredentials = { _ in
                    throw expectedError
                }
            } operation: {
                try await GetCredentialsUseCase.liveValue.execute(server)
            }
        }
    }
}

private enum TestError: Error, Equatable {
    case keychainError
}
