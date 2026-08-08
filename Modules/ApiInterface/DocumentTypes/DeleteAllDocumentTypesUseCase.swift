import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllDocumentTypesUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllDocumentTypesUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllDocumentTypes: DeleteAllDocumentTypesUseCase {
        get { self[DeleteAllDocumentTypesUseCase.self] }
        set { self[DeleteAllDocumentTypesUseCase.self] = newValue }
    }
}
