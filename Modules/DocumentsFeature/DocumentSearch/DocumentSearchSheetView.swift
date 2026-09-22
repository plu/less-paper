import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchSheetView: View {

    var body: some View {
        VStack(spacing: .x0) {
            Field(padding: .x0) {
                HStack(spacing: .x0) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.m3Primary)
                        .padding(.leading, .x2 + .x3)
                    // A search field, not prose: the observed default capitalised the first
                    // letter of the query, which is not what anyone means when they type a tag's
                    // name.
                    TextField(String(localized: .search), text: searchTextBinding)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .padding(.leading, .x2)
                        .submitLabel(.search)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .onSubmit { send(.submitted) }
                }
            }
            .padding(.horizontal, .x4)
            .padding(.top, .x4)

            List {
                DocumentSearchResultsView(store: store)
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.m3Surface)
        // The keyboard has to be up before the sheet settles, otherwise the first thing the user
        // does after tapping Search is tap again.
        .task { isSearchFocused = true }
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

    @FocusState
    private var isSearchFocused: Bool
}

#Preview {
    DocumentSearchSheetView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentSearchReducer()
            }
        )
    )
}
