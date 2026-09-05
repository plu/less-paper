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

        @Shared(.permissions(server))
        var permissions: [Permission]?

        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        // ui_settings carries the user and the flattened effective permission set. Fetching
        // /api/users/<id>/ for the same data additionally requires view_user, which a restricted
        // user does not have - so the second request cost a permission and bought nothing.
        let uiSettings = try await uiSettingsRepository.getUISettings(
            input: .init(),
            server: server
        )

        $cache.withLock { $0 = uiSettings.user }
        $permissions.withLock { $0 = uiSettings.permissions }

        return uiSettings.user
    }
}
