import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

// The first row of the documents list in both modes, so the way out of search is always where the
// way in was.
@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchBarView: View {

    var body: some View {
        HStack(spacing: .x3) {
            DocumentSearchField(
                isFocused: $isSearchFocused,
                submitted: { send(.submitted) },
                text: searchTextBinding
            )
            // The field's own `X` wipes the text and leaves the user in the field with the keyboard
            // up, which is not a way out. Shown on content as well as on focus because a query that
            // survived a push still needs one.
            if isSearchFocused || !store.searchText.isEmpty {
                Button(String(localized: .cancel)) {
                    isSearchFocused = false
                    send(.cancelButtonTapped)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.m3Primary)
                .lineLimit(1)
            }
        }
        .animation(.default, value: isSearchFocused)
        .onChange(of: store.dismissalCount) { isSearchFocused = false }
    }

    init(store: StoreOf<DocumentSearchReducer>) {
        self.store = store
    }

    let store: StoreOf<DocumentSearchReducer>

    // An explicit binding rather than `$store.searchText`: the reducer has no `BindingReducer`, so
    // a bindable write would set the text straight into state and never run the debounce. Redundant
    // writes are dropped for the reason DocumentFilterView gives — SwiftUI makes one on appear and
    // one on teardown, and each would cost a 400ms debounce and a request for a search that had not
    // changed.
    var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: {
                guard $0 != store.searchText else {
                    return
                }
                send(.searchTextChanged($0))
            }
        )
    }

    // Deliberately not raised on appear: the field is a row of the documents list now rather than
    // the only thing in a sheet, and a list that takes the keyboard the moment it is shown hides
    // the documents it exists to show.
    @FocusState
    private var isSearchFocused: Bool
}

#Preview {
    DocumentSearchBarView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentSearchReducer()
            }
        )
    )
}
