import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetGroupsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [Group]
}

extension GetGroupsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getGroups: GetGroupsUseCase {
        get { self[GetGroupsUseCase.self] }
        set { self[GetGroupsUseCase.self] = newValue }
    }
}
