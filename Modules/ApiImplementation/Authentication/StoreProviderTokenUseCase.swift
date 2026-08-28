import ApiInterface
import Dependencies
import Foundation

extension StoreProviderTokenUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: { server, token in
            @Dependency(\.keychain)
            var keychain

            // No password: the credential is the token, and there is nothing else to keep.
            try await keychain.storeCredentials(
                credentials: .init(password: nil, token: token),
                server: server
            )
        }
    )
}
