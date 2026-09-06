import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: SavedViewListReducer.self)
public struct SavedViewListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleSavedViews.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleSavedViews, action: \.savedViews))) { store in
                SavedViewRowView(store: store)
            }
        }
        .overlay(emptyListView())
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.savedViews)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.savedViewForm, action: \.destination.savedViewForm)
        ) { store in
            SavedViewFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            if store.canCreate {
                Button(action: {
                    send(.createSavedViewButtonTapped)
                }) {
                    Label(.createSavedView, systemImage: "plus")
                }
            }
        }
    }

    public init(store: StoreOf<SavedViewListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SavedViewListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.savedViews.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "line.3.horizontal.decrease",
                    title: .noSavedViewsFound
                ) {
                    // No call to action for someone who cannot create saved views: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.canCreate {
                        Button {
                            send(.createSavedViewButtonTapped)
                        } label: {
                            Label(.createSavedView, systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary())
                    }
                }
            }
        }
    }
}

#Preview {
    SavedViewListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                SavedViewListReducer()
            }
        )
    )
}
