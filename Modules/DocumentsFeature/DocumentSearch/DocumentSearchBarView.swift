import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

// The first row of the documents list in both modes, so the way out of search is always where the
// way in was.
@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchBarView: View {

    var body: some View {
        HStack(spacing: .x0) {
            DocumentSearchField(
                isFocused: $isSearchFocused,
                submitted: { send(.submitted) },
                text: searchTextBinding
            )
            // The field's own `X` wipes the text and leaves the user in the field with the keyboard
            // up, which is not a way out. Shown on content as well as on focus because a query that
            // survived a push still needs one.
            //
            // An icon rather than the word, with the tap target spelled out: the glyph is about
            // 15pt on its own, and this one sits a thumb's width from a field people are typing
            // into. The label is what VoiceOver announces and what the journey looks for.
            //
            // Always in the hierarchy, collapsed and faded out when there is nothing to cancel,
            // rather than inside an `if`. A list row does not run a transition on a structural
            // change: with the `if`, the button was inserted at full opacity on the same frame the
            // field started narrowing — it arrived before the space it arrives in existed, which
            // was measured frame by frame, not assumed. Width and opacity are ordinary animatable
            // values, so the two now move together.
            Button {
                isSearchFocused = false
                send(.cancelButtonTapped)
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.m3Primary)
                    .frame(width: .x5 + .x3, height: .x5 + .x3)
                    .contentShape(.rect)
            }
            .accessibilityHidden(!isCancelVisible)
            .accessibilityLabel(.cancel)
            .buttonStyle(.plain)
            .disabled(!isCancelVisible)
            .frame(width: isCancelVisible ? .x5 + .x3 : .x0)
            .opacity(isCancelVisible ? 1 : 0)
            .clipped()
        }
        // Keyed on the button rather than on focus: it is the button's presence that changes the
        // field's width, and text arriving without a focus change — a query that survived a push —
        // moves the same layout.
        .animation(.default, value: isCancelVisible)
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

    private var isCancelVisible: Bool {
        isSearchFocused || !store.searchText.isEmpty
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
