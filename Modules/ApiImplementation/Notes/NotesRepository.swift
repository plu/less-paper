import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct NotesRepository: Sendable {

    var createNote: @Sendable (
        _ documentId: Document.Id,
        _ input: CreateNoteInput,
        _ server: Server
    ) async throws -> [Note]

    var deleteNote: @Sendable (
        _ documentId: Document.Id,
        _ noteId: Note.Id,
        _ server: Server
    ) async throws -> [Note]

    var getNotes: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [Note]
}

extension NotesRepository: TestDependencyKey {

    static let previewValue = Self(
        createNote: { _, _, _ in [.testValue()] },
        deleteNote: { _, _, _ in [] },
        getNotes: { _, _ in [.testValue()] }
    )

    static let testValue = Self(
        createNote: { _, _, _ in [.testValue()] },
        deleteNote: { _, _, _ in [] },
        getNotes: { _, _ in [.testValue()] }
    )
}

extension DependencyValues {

    var notesRepository: NotesRepository {
        get { self[NotesRepository.self] }
        set { self[NotesRepository.self] = newValue }
    }
}

extension NotesRepository: DependencyKey {
    static let liveValue = Self(
        createNote: createNote(documentId:input:server:),
        deleteNote: deleteNote(documentId:noteId:server:),
        getNotes: getNotes(documentId:server:)
    )
}

private extension NotesRepository {

    // All three verbs answer with the document's complete note list, so a create or a delete is
    // also a refresh and never needs a follow-up read.

    static func createNote(
        documentId: Document.Id,
        input: CreateNoteInput,
        server: Server
    ) async throws -> [Note] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/notes/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteNote(
        documentId: Document.Id,
        noteId: Note.Id,
        server: Server
    ) async throws -> [Note] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/notes/",
                method: .delete,
                query: [("id", "\(noteId.rawValue)")]
            ))
            .value
    }

    static func getNotes(
        documentId: Document.Id,
        server: Server
    ) async throws -> [Note] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/notes/",
                method: .get
            ))
            .value
    }
}
