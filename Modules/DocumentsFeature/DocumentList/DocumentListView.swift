import Components
import ComposableArchitecture
import ShareFeature
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
public struct DocumentListView: View {
    public var body: some View {
        AdaptiveNavigationView(path: $store.scope(state: \.path, action: \.path)) {
            List {
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
