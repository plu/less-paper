import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension GetCurrentUserUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetCurrentUserUseCase {

    static func execute(
        server: Server
    ) async throws -> User {
        @Shared(.currentUser(server))
        var cache: User?

        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        @Dependency(\.usersRepository)
        var usersRepository

        let uiSettings = try await uiSettingsRepository.getUISettings(
            input: .init(),
            server: server
        )

        let currentUser = try await usersRepository.getUser(
            input: .init(id: uiSettings.user.id),
            server: server
        )

        $cache.withLock { $0 = currentUser }

        return currentUser
    }
}
