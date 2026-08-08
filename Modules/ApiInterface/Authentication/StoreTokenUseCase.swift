import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct StoreTokenUseCase: Sendable {

    public var execute: @Sendable (
        _ code: String?,
        _ password: String,
        _ server: Server,
        _ username: String
    ) async throws -> Void
}

extension StoreTokenUseCase: TestDependencyKey {
    public static let previewValue = Self(
        execute: { _, _, _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _, _, _ in }
    )
}

public extension DependencyValues {
    var storeToken: StoreTokenUseCase {
        get { self[StoreTokenUseCase.self] }
        set { self[StoreTokenUseCase.self] = newValue }
    }
}
