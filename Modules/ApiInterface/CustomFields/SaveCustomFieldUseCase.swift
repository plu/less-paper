import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveCustomFieldUseCase: Sendable {

    public var execute: @Sendable (
        _ id: CustomField.Id?,
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput
}

extension SaveCustomFieldUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveCustomField: SaveCustomFieldUseCase {
        get { self[SaveCustomFieldUseCase.self] }
        set { self[SaveCustomFieldUseCase.self] = newValue }
    }
}
