import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetUsersUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [User]
}

extension GetUsersUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getUsers: GetUsersUseCase {
        get { self[GetUsersUseCase.self] }
        set { self[GetUsersUseCase.self] = newValue }
    }
}
