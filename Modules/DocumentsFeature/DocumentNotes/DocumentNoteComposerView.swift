import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentNotesReducer.self)
struct DocumentNoteComposerView: View {

    var body: some View {
        HStack(alignment: .bottom, spacing: .x3) {
            TextField(text: $store.draft, axis: .vertical) {
                Text(.addNote)
            }
            .font(.body)
            .lineLimit(1 ... 5)
            .padding(.horizontal, .x2 + .x3)
            .padding(.vertical, .x3)
            .frame(minHeight: 44)
            // Matching Field's background and outline rather than reusing it: Field clips to a
            // Capsule, which cannot hold five lines of text.
            .background(Color.m3SurfaceBright)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(Color.m3Outline, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

            Button {
                send(.addButtonTapped)
            } label: {
                Image(systemName: "arrow.up")
            }
            .accessibilityLabel(.addNote)
            .buttonStyle(.primary(isLoading: $store.isCreating))
            .disabled(!store.canCreate)
            .fixedSize()
        }
    }

    @Bindable
    var store: StoreOf<DocumentNotesReducer>
}

#Preview {
    DocumentNoteComposerView(
        store: Store(
            initialState: DocumentNotesReducer.State.testValue(draft: "Chase the supplier"),
            reducer: {
                DocumentNotesReducer()
            }
        )
    )
    .padding()
}
