import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct RemoveOfflineDocumentUseCase: Sendable {

    public var execute: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void
}

extension RemoveOfflineDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in })

    public static let testValue = Self(execute: { _, _ in })
}

public extension DependencyValues {

    var removeOfflineDocument: RemoveOfflineDocumentUseCase {
        get { self[RemoveOfflineDocumentUseCase.self] }
        set { self[RemoveOfflineDocumentUseCase.self] = newValue }
    }
}
