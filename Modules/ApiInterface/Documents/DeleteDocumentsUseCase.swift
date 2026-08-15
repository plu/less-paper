import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteDocumentsUseCase: Sendable {

    public var execute: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}

extension DeleteDocumentsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteDocuments: DeleteDocumentsUseCase {
        get { self[DeleteDocumentsUseCase.self] }
        set { self[DeleteDocumentsUseCase.self] = newValue }
    }
}
