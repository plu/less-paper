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
        // Pinned rather than left to its default: unpinned it is revealed by the first pull, so a
        // pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
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
            if store.permissions.can(.addTag) {
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
                    if store.permissions.can(.addTag) {
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
