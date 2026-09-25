import Components
import ComposableArchitecture
import SwiftUI

// The first row of the documents list in both modes, so the way out of search is always where the
// way in was.
@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchBarView: View {

    var body: some View {
        SearchBar(
            text: searchTextBinding,
            cancelled: { send(.cancelButtonTapped) },
            dismissalCount: store.dismissalCount,
            submitted: { send(.submitted) }
        )
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
