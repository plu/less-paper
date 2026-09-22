import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchSheetView: View {

    var body: some View {
        // `isScrollingEnabled: false` because the content carries its own `List`: wrapped in
        // `Sheet`'s ScrollView instead, the results would scroll inside a scroll view that has no
        // height of its own.
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: .search, left: leftHeader)
        } content: {
            VStack(spacing: .x0) {
                DocumentSearchField(
                    isFocused: $isSearchFocused,
                    submitted: { send(.submitted) },
                    text: searchTextBinding
                )
                .padding(.horizontal, .x4)
                .padding(.top, .x4)

                // Styled as the settings lists are — default list style, surface background,
                // `m3SurfaceContainer` rows — so a result reads like a row on the Tags or
                // Correspondents screen rather than like a third kind of list.
                List {
                    DocumentSearchResultsView(store: store)
                }
                .background(Color.m3SurfaceContainerLowest)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
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

    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }
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
