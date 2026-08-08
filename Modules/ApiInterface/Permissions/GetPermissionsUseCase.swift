import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetPermissionsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server,
        _ type: PermissionsType?
    ) async throws -> GetPermissionsOutput
}

extension GetPermissionsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getPermissions: GetPermissionsUseCase {
        get { self[GetPermissionsUseCase.self] }
        set { self[GetPermissionsUseCase.self] = newValue }
    }
}
