import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import DocumentsFeature
import SwiftUI

@ViewAction(for: OfflineListReducer.self)
public struct OfflineListView: View {

    private var list: some View {
        List {
            ForEach(store.scope(state: \.rows, action: \.rows)) { store in
                OfflineRowView(store: store)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.x3)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.offline)
        .onDisappear { send(.onDisappear) }
        .overlay(emptyListView())
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    // Its own NavigationStack rather than `Searchable`'s: the pushes are driven by the reducer's
    // StackState, and `Searchable` builds an unbound stack that a path binding cannot reach.
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            // Attached only when there is something to search. The field sits above the list and
            // hides by scrolling out of view, so over an empty list it has nowhere to go and simply
            // stays on screen - and a search field above nothing cannot do anything anyway.
            //
            // The searchText half is not belt and braces: a query matching nothing empties the
            // list, and without it the field would vanish mid-search, taking the query with it.
            if !store.rows.isEmpty || !store.searchText.isEmpty {
                list.searchable(text: $store.searchText)
            } else {
                list
            }
        } destination: { store in
            switch store.case {
            case let .documentDetail(store):
                DocumentDetailView(store: store)
            }
        }
    }

    public init(store: StoreOf<OfflineListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<OfflineListReducer>

    // Two different nothings: nothing saved offline yet, which is worth explaining, and a search that
    // matched none of what is here, which is not. Without the second a filtered-out list is a blank
    // screen that looks like the offline documents have gone.
    @ViewBuilder
    private func emptyListView() -> some View {
        if store.offlineDocuments.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "arrow.down.circle", title: .noOfflineDocuments) {
                    Text(.noOfflineDocumentsMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.m3OnSurface)
                        .multilineTextAlignment(.center)
                }
            }
        } else if store.rows.isEmpty, !store.searchText.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "magnifyingglass", title: .noOfflineDocumentsFound)
            }
        }
    }
}

#Preview {
    OfflineListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                OfflineListReducer()
            }
        )
    )
}
