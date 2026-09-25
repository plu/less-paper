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
            // Outside any branch on whether there is something to search: the documents list keeps
            // its bar over an empty list too, and a row that comes and goes takes the query with
            // it. It scrolls away with the rows rather than hiding above them, which is what
            // `.searchable` did and what made the two lists look unrelated.
            SearchBar(
                text: $store.searchText,
                cancelled: { send(.searchCancelled) }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .padding(.bottom, .x3)
            .padding(.horizontal, .x3)
            .padding(.top, .x3)
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
        // Dragging the rows is as much a way of saying "let me see them" as scrolling a sheet was.
        .scrollDismissesKeyboard(.immediately)
        .task { await send(.onAppear).finish() }
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            list
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

    // Two different nothings: nothing saved offline yet, which is worth explaining, and a search
    // that matched none of what is here, which is not. Without the second a filtered-out list is a
    // blank screen that looks like the offline documents have gone.
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
