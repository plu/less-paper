import ApiInterface
import Dependencies

extension StoreServerWithoutTokenUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: { server in
            @Dependency(\.keychain)
            var keychain

            // Both nil: no password, no token. Keychain.storeCredentials removes the old entries
            // and skips writing new ones for the nil fields.
            try await keychain.storeCredentials(
                credentials: .init(password: nil, token: nil),
                server: server
            )
        }
    )
}
