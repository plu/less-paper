import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteNoteUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ noteId: Note.Id,
        _ server: Server
    ) async throws -> [Note]
}

extension DeleteNoteUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in [] }
    )

    public static let testValue = Self(
        execute: { _, _, _ in [] }
    )
}

public extension DependencyValues {

    var deleteNote: DeleteNoteUseCase {
        get { self[DeleteNoteUseCase.self] }
        set { self[DeleteNoteUseCase.self] = newValue }
    }
}
