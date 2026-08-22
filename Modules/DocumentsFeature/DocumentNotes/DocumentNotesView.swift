import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentNotesReducer.self)
struct DocumentNotesView: View {

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentNotesReducer>

    var isReadOnly = false

    @ViewBuilder
    private func content() -> some View {
        if let loadError = store.loadError {
            EmptyListView(
                systemImage: "note.text",
                title: .init(stringLiteral: loadError)
            ) {
                Button {
                    send(.retryLoadButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        } else if let notes = store.notes {
            if notes.isEmpty {
                // No button: editing, the composer pinned below the list is already the call to
                // action, and read-only has nothing to offer.
                EmptyListView(
                    systemImage: "note.text",
                    title: .noNotesFound
                )
            } else {
                List(notes) { note in
                    DocumentNoteRowView(
                        isDeleting: store.deletingNoteId == note.id,
                        note: note,
                        deleteButtonTapped: isReadOnly ? nil : { send(.deleteButtonTapped(note.id)) }
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

#Preview {
    DocumentNotesView(
        store: Store(
            initialState: DocumentNotesReducer.State.testValue(notes: [.testValue()]),
            reducer: {
                DocumentNotesReducer()
            }
        )
    )
}
