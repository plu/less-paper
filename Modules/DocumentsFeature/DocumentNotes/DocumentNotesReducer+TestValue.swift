import ApiInterface
import Foundation
import IdentifiedCollections

extension DocumentNotesReducer.State {

    static func testValue(
        deletingNoteId: Note.Id? = nil,
        documentId: Document.Id = 1,
        draft: String = "",
        isCreating: Bool = false,
        loadError: String? = nil,
        notes: IdentifiedArrayOf<Note>? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            documentId: documentId,
            server: server
        )
        state.deletingNoteId = deletingNoteId
        state.draft = draft
        state.isCreating = isCreating
        state.loadError = loadError
        state.notes = notes
        return state
    }
}
