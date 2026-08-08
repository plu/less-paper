import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteDocumentTypeUseCase: Sendable {

    public var execute: @Sendable (
        _ id: DocumentType.Id,
        _ server: Server
    ) async throws -> Void
}

extension DeleteDocumentTypeUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteDocumentType: DeleteDocumentTypeUseCase {
        get { self[DeleteDocumentTypeUseCase.self] }
        set { self[DeleteDocumentTypeUseCase.self] = newValue }
    }
}
