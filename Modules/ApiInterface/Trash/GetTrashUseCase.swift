import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetTrashUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> GetTrashOutput
}

extension GetTrashUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _ in .testValue() }
    )
}

public extension DependencyValues {

    var getTrash: GetTrashUseCase {
        get { self[GetTrashUseCase.self] }
        set { self[GetTrashUseCase.self] = newValue }
    }
}
