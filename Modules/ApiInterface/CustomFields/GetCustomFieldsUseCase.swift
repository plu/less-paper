import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetCustomFieldsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [CustomField]
}

extension GetCustomFieldsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getCustomFields: GetCustomFieldsUseCase {
        get { self[GetCustomFieldsUseCase.self] }
        set { self[GetCustomFieldsUseCase.self] = newValue }
    }
}
