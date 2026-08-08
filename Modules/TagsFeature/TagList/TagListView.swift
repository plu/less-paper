import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: TagListReducer.self)
public struct TagListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.tags, action: \.tags))) { store in
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
            Button(action: {
                send(.createTagButtonTapped)
            }) {
                Label(.createTag, systemImage: "plus")
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
