import Dependencies
import DependenciesMacros
import Foundation

// Refresh and saving offline share this use case, and they want opposite things from a document
// that was removed while the fetch was in flight: the add path must write it, a refresh must not
// resurrect it.
public enum SaveOfflineMode: Equatable, Sendable {
    case add
    case refreshExisting
}

@DependencyClient
public struct SaveOfflineDocumentUseCase: Sendable {

    public var execute: @Sendable (
        _ document: Document,
        _ server: Server,
        _ mode: SaveOfflineMode
    ) async throws -> Void
}

extension SaveOfflineDocumentUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _, _ in })

    public static let testValue = Self(execute: { _, _, _ in })
}

public extension DependencyValues {

    var saveOfflineDocument: SaveOfflineDocumentUseCase {
        get { self[SaveOfflineDocumentUseCase.self] }
        set { self[SaveOfflineDocumentUseCase.self] = newValue }
    }
}
