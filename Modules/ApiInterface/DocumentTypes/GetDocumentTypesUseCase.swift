import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentTypesUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [DocumentType]
}

extension GetDocumentTypesUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getDocumentTypes: GetDocumentTypesUseCase {
        get { self[GetDocumentTypesUseCase.self] }
        set { self[GetDocumentTypesUseCase.self] = newValue }
    }
}
