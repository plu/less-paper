import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension StoreTokenUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(code:password:server:username:)
    )
}

private extension StoreTokenUseCase {

    static func execute(
        code: String?,
        password: String,
        server: Server,
        username: String
    ) async throws {
        @Dependency(\.keychain)
        var keychain

        @Dependency(\.authenticationRepository)
        var repository

        let token = try await repository.getToken(
            input: .init(
                code: code,
                password: password,
                username: username
            ),
            server: server
        ).token

        try await keychain.storeCredentials(
            credentials: .init(
                password: password,
                token: token
            ),
            server: server
        )
    }
}
