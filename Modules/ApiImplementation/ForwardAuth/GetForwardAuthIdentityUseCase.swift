import ApiInterface
import Dependencies

extension GetForwardAuthIdentityUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetForwardAuthIdentityUseCase {

    static func execute(server: Server) async throws -> String? {
        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        @Dependency(\.usersRepository)
        var usersRepository

        do {
            let settings = try await uiSettingsRepository.getUISettings(
                input: .init(),
                server: server
            )
            let user = try await usersRepository.getUser(
                input: .init(id: settings.user.id),
                server: server
            )
            return user.username
        } catch is ApiError {
            // A gate-only proxy passes the cookie-authenticated request through to paperless,
            // which answers 401 (no Location, because the cookie already got past the proxy).
            // That's the signal that the ordinary token login is still needed.
            //
            // 5xx and network failures surface as APIError.unacceptableStatusCode and URLError
            // respectively and are re-thrown - they are real problems, not "gate-only".
            return nil
        }
    }
}
