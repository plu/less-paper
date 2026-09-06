import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: TagListReducer.self)
public struct TagListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleTags.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleTags, action: \.tags))) { store in
                TagRowView(store: store)
            }
        }
        .overlay(emptyListView())
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
