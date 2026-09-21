import Components
import ComposableArchitecture
import DesignTokens
import ShareFeature
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
public struct DocumentListView: View {
    public var body: some View {
        AdaptiveNavigationView(path: $store.scope(state: \.path, action: \.path)) {
            List {
                if store.isTipInvitationVisible {
                    // Animated on both paths: the row is answered at most once in a user's
                    // lifetime, and having it vanish between two frames reads as a glitch rather
                    // than as the app acknowledging what they just did.
                    TipInvitationBanner(
                        tapped: { send(.tipInvitationTapped, animation: .default) },
                        dismissed: { send(.tipInvitationDismissed, animation: .default) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.x3)
                }
                // Rows default to `systemBackground`, which is black in dark mode and so paints over
                // the list's `m3SurfaceContainerLowest`. Invisible in light mode, where both are white.
                ForEach(Array(store.scope(state: \.documents, action: \.documents))) { store in
                    DocumentRowView(store: store)
                        .documentSelectionOverlay(
                            document: store.document.id,
                            store: documentSelectionStore
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .onAppear { send(.onRowAppear(store.document)) }
                        .padding(.x3)
                }
                if store.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.large)
                            .id(UUID())
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.x3)
                }
                Spacer()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .background(Color.m3SurfaceContainerLowest)
            .documentListBottomToolbar(store: store, viewAction: send)
            .documentListTopLeadingToolbar(store: store, type: .documents, viewAction: send)
            .documentListTopTrailingToolbar(store: store, viewAction: send)
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(store.navigationTitle)
            .overlay(alignment: .bottom) {
                DocumentListStatusBarView(store: store)
            }
            .overlay(documentSelectionLoadingView())
            .overlay(DocumentListEmptyView(store: store))
            .refreshable { await send(.onRefresh).finish() }
            .scrollContentBackground(.hidden)
            .searchable(text: searchTextBinding, prompt: Text(.search))
            .searchSuggestions {
                DocumentSearchResultsView(store: searchStore)
            }
            // Breaks this view's alphabetical modifier order deliberately. `onSubmit` writes the
            // action into the environment of the subtree below it, and the search field is created
            // by `.searchable` above — placed any earlier, the field never sees it and return does
            // nothing.
            .onSubmit(of: .search) { searchStore.send(.view(.submitted)) }
            .task { await send(.onAppear).finish() }
        } destination: { store in
            switch store.case {
            case let .documentDetail(store):
                DocumentDetailView(store: store)
            }
        } placeholder: {
            DocumentDetailPlaceholderView()
        }
        // The reducer decides whether opening a document pushes or replaces, so it has to be told
        // which layout is on screen. Read here rather than inside the container, because the
        // container is generic over features that may not care.
        .onAppear { send(.onLayoutChanged(isSplit: horizontalSizeClass == .regular)) }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            send(.onLayoutChanged(isSplit: sizeClass == .regular))
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.documentFilter,
                action: \.destination.documentFilter
            )
        ) { store in
            DocumentFilterView(store: store)
                .presentationDetents([.sheet])
        }
    }

    public init(store: StoreOf<DocumentListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<DocumentListReducer>

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @ViewBuilder
    private func documentSelectionLoadingView() -> some View {
        if store.documentSelection.isLoading {
            ZStack {
                ProgressView()
                    .controlSize(.large)
                    .id(UUID())
            }
        }
    }

    private var documentSelectionStore: StoreOf<DocumentSelectionReducer> {
        store.scope(
            state: \.documentSelection,
            action: \.documentSelection
        )
    }

    // Sent through the scoped store rather than as `store.send(.search(…))`: this view is
    // `@ViewAction`, whose `send` would wrap the action in `.view(…)`, and the macro rejects
    // `store.send` outright — warnings are errors in every configuration here.
    private var searchStore: StoreOf<DocumentSearchReducer> {
        store.scope(
            state: \.search,
            action: \.search
        )
    }

    // An explicit binding rather than `$store.search.searchText`: that is a chained lookup, so the
    // store would only ever see `.binding(.set(\.search, …))` on the parent, writing straight into
    // child state and never running the debounce. Redundant writes are dropped for the reason
    // DocumentFilterView gives — SwiftUI makes one on appear and one on teardown, and each would
    // cost a 400ms debounce and a request for a search that had not changed.
    var searchTextBinding: Binding<String> {
        Binding(
            get: { store.search.searchText },
            set: {
                guard $0 != store.search.searchText else {
                    return
                }
                searchStore.send(.view(.searchTextChanged($0)))
            }
        )
    }
}

#Preview {
    DocumentListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentListReducer()
            }
        )
    )
}
