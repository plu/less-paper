import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: TagListReducer.self)
public struct TagListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleTags, action: \.tags))) { store in
                TagRowView(store: store)
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
        .navigationTitle(.tags)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.tagForm, action: \.destination.tagForm)
        ) { store in
            TagFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            if store.canCreate {
                Button(action: {
                    send(.createTagButtonTapped)
                }) {
                    Label(.createTag, systemImage: "plus")
                }
            }
        }
    }

    public init(store: StoreOf<TagListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<TagListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.tags.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "tag",
                    title: .noTagsFound
                ) {
                    // No call to action for someone who cannot create tags: there is nothing there,
                    // and they cannot change that. Saying why would explain a boundary this app is
                    // not the one enforcing.
                    if store.canCreate {
                        Button {
                            send(.createTagButtonTapped)
                        } label: {
                            Label(.createTag, systemImage: "plus.circle")
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
    TagListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                TagListReducer()
            }
        )
    )
}
