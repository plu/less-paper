import ApiInterface
import Dependencies
import Foundation

extension AuthenticationProvider: @retroactive DependencyKey {
    public static let liveValue = Self(
        getToken: getToken(server:)
    )
}

public extension AuthenticationProvider {

    static let integrationTest = Self(
        getToken: { _ in
            @Dependency(\.authenticationRepository)
            var repository

            return try await repository.getToken(
                input: .testValue(),
                server: .testValue()
            ).token
        }
    )
}

private extension AuthenticationProvider {

    static func getToken(
        server: Server
    ) async throws -> String? {
        @Dependency(\.keychain)
        var keychain

        return try await keychain.getCredentials(
            server: server
        ).token
    }
}
