import Dependencies
import DependenciesMacros
import Foundation

/// Stores a token that was obtained from an identity provider rather than from a password.
///
/// Separate from `StoreTokenUseCase`, which asks paperless for a token given a username and a
/// password. By the time this is called the token already exists; there is nothing left to ask.
@DependencyClient
public struct StoreProviderTokenUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server,
        _ token: String
    ) async throws -> Void
}

extension StoreProviderTokenUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var storeProviderToken: StoreProviderTokenUseCase {
        get { self[StoreProviderTokenUseCase.self] }
        set { self[StoreProviderTokenUseCase.self] = newValue }
    }
}
