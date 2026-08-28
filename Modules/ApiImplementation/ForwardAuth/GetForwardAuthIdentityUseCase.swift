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
            // The probe has to ask as nobody. With a token attached, any healthy server answers
            // 200 and every *edit* of an ordinary server reads as remote-user mode - which then
            // stores that server with no token and no password, logging it out. Overriding the
            // provider rather than stripping a header, because the provider is the one place
            // ApiClientDelegate reads the token from.
            return try await withDependencies {
                $0.authenticationProvider.getToken = { _ in nil }
            } operation: {
                let settings = try await uiSettingsRepository.getUISettings(
                    input: .init(),
                    server: server
                )
                let user = try await usersRepository.getUser(
                    input: .init(id: settings.user.id),
                    server: server
                )
                return user.username
            }
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
