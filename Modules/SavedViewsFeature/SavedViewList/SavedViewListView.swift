import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: SavedViewListReducer.self)
public struct SavedViewListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleSavedViews, action: \.savedViews))) { store in
                SavedViewRowView(store: store)
            }
        }
        .overlay(emptyListView())
        // Left to its default so the field stays out of the way until pulled down. That costs
        // something real and known: the first pull of a pull-to-refresh travels through the field
        // before the refresh engages. These screens were pinned for exactly that reason and
        // deliberately unpinned again — a row of every screen spent on a control most visits never
        // use was the worse trade.
        .searchable(text: $store.searchText)
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
