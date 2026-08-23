import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteCustomFieldUseCase: Sendable {

    public var execute: @Sendable (
        _ id: CustomField.Id,
        _ server: Server
    ) async throws -> DeleteCustomFieldOutput
}

extension DeleteCustomFieldUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {
    var deleteCustomField: DeleteCustomFieldUseCase {
        get { self[DeleteCustomFieldUseCase.self] }
        set { self[DeleteCustomFieldUseCase.self] = newValue }
    }
}
