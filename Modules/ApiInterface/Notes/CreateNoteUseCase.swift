import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct CreateNoteUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ input: CreateNoteInput,
        _ server: Server
    ) async throws -> [Note]
}

extension CreateNoteUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _, _, _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var createNote: CreateNoteUseCase {
        get { self[CreateNoteUseCase.self] }
        set { self[CreateNoteUseCase.self] = newValue }
    }
}
