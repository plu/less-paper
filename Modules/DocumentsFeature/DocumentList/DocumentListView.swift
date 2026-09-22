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
                // The same `DocumentSearchField` the sheet shows, read-only, carrying whatever
                // the sheet was last closed on — so the list says what is currently searched and
                // tapping it goes back in to refine. Collapsed into one element for VoiceOver:
                // it is a button that opens a sheet, not a field anyone can type into here.
                Button {
                    send(.searchButtonTapped)
                } label: {
                    DocumentSearchField(query: store.search.searchText)
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(.search)
                        .accessibilityValue(store.search.searchText)
                }
                .buttonStyle(.plain)
                // The whole control, not just the glyphs: a Button's label only takes taps where
                // it draws, and the field is mostly empty space.
                .contentShape(.rect)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .padding(.horizontal, .x3)
                .padding(.top, .x3)
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
        // Presented against a plain flag with the child store scoped in, rather than through
        // `destination`: the search is a permanent child of this state, so closing the sheet has
        // to leave the query and its results intact for the next time it opens.
        // Full height rather than the filter sheet's `.sheet` detent: the results run to seven
        // sections, and a 600pt sheet with the keyboard up leaves almost none of them visible.
        .sheet(isPresented: $store.isSearchPresented) {
            DocumentSearchSheetView(store: searchStore)
                .presentationDetents([.large])
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

    private var searchStore: StoreOf<DocumentSearchReducer> {
        store.scope(
            state: \.search,
            action: \.search
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
