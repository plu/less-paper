import Dependencies
import DependenciesMacros

@DependencyClient
public struct StoreServerWithoutTokenUseCase: Sendable {

    // Persists the Server for remote-user mode, where the proxy injects a trusted identity and
    // paperless takes it - so there is no token or password to store. Split from StoreTokenUseCase
    // because a use case named "store token" that stores nothing is worse than a second use case.
    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension StoreServerWithoutTokenUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in }
    )

    public static let testValue = Self()
}

public extension DependencyValues {

    var storeServerWithoutToken: StoreServerWithoutTokenUseCase {
        get { self[StoreServerWithoutTokenUseCase.self] }
        set { self[StoreServerWithoutTokenUseCase.self] = newValue }
    }
}
