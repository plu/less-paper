import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension GetCredentialsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetCredentialsUseCase {
    static func execute(
        server: Server
    ) async throws -> Credentials {
        @Dependency(\.keychain)
        var keychain

        return try await keychain.getCredentials(server: server)
    }
}
