import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections

@Reducer
public struct DocumentNotesReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case deleteConfirmed(Note.Id)
        case notesResult(Request, Result<[Note], Error>)
        case view(View)

        public enum Request: Equatable {
            case create
            case delete
            case load
        }

        public enum View {
            case addButtonTapped
            case deleteButtonTapped(Note.Id)
            case onAppear
            case retryLoadButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        var deletingNoteId: Note.Id?

        let documentId: Document.Id

        var draft = ""

        var isCreating = false

        var isLoading = false

        var loadError: String?

        // nil until the first load lands. An empty array means "loaded, and there are none" — the
        // two states drive different views, so they cannot share a value.
        var notes: IdentifiedArrayOf<Note>?

        let server: Server

        var canCreate: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
        }

        init(
            documentId: Document.Id,
            server: Server
        ) {
            self.documentId = documentId
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .deleteConfirmed(noteId):
                state.deletingNoteId = noteId
                return .runDeleteNote(
                    documentId: state.documentId,
                    noteId: noteId,
                    server: state.server
                )
            case let .notesResult(request, result):
                switch request {
                case .create:
                    state.isCreating = false
                case .delete:
                    state.deletingNoteId = nil
                case .load:
                    state.isLoading = false
                }
                switch result {
                case let .failure(error):
                    // Only a failed load leaves the section without anything to show. A failed
                    // create or delete leaves the list on screen still valid, so it only toasts —
                    // and a failed create keeps the draft rather than losing the user's text.
                    if request == .load {
                        state.loadError = error.localizedDescription
                    }
                    return .toast(error)
                case let .success(notes):
                    state.loadError = nil
                    state.notes = IdentifiedArray(uniqueElements: notes)
                    if request == .create {
                        state.draft = ""
                    }
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .addButtonTapped:
                    guard state.canCreate else {
                        return .none
                    }
                    state.isCreating = true
                    return .runCreateNote(
                        documentId: state.documentId,
                        input: CreateNoteInput(
                            note: state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        server: state.server
                    )
                case let .deleteButtonTapped(noteId):
                    // A swipe on a row the latest response has already removed must not open a
                    // dialog that deletes nothing.
                    guard state.notes?[id: noteId] != nil else {
                        return .none
                    }
                    return .runConfirmDelete(noteId: noteId)
                case .onAppear:
                    // A failed load is not retried silently on the next appearance; that is what
                    // the retry button is for. Switching sections away and back must not refetch
                    // either, which is what the nil check buys.
                    guard state.notes == nil, state.loadError == nil, !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetNotes(
                        documentId: state.documentId,
                        server: state.server
                    )
                case .retryLoadButtonTapped:
                    guard !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    state.loadError = nil
                    return .runGetNotes(
                        documentId: state.documentId,
                        server: state.server
                    )
                }
            case .binding:
                return .none
            }
        }
    }
}
