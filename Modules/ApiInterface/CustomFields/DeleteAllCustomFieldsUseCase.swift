import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllCustomFieldsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllCustomFieldsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllCustomFields: DeleteAllCustomFieldsUseCase {
        get { self[DeleteAllCustomFieldsUseCase.self] }
        set { self[DeleteAllCustomFieldsUseCase.self] = newValue }
    }
}
