import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetCurrentUserUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> User
}

extension GetCurrentUserUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _ in .testValue() }
    )
}

public extension DependencyValues {

    var getCurrentUser: GetCurrentUserUseCase {
        get { self[GetCurrentUserUseCase.self] }
        set { self[GetCurrentUserUseCase.self] = newValue }
    }
}
