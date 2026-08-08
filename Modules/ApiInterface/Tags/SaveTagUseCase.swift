import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveTagUseCase: Sendable {

    public var execute: @Sendable (
        _ id: Tag.Id?,
        _ input: SaveTagInput,
        _ server: Server
    ) async throws -> SaveTagOutput
}

extension SaveTagUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveTag: SaveTagUseCase {
        get { self[SaveTagUseCase.self] }
        set { self[SaveTagUseCase.self] = newValue }
    }
}
