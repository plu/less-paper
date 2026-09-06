import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentTypeListReducer.self)
public struct DocumentTypeListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleDocumentTypes, action: \.documentTypes))) { store in
                DocumentTypeRowView(store: store)
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
        .navigationTitle(.documentTypes)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.documentTypeForm, action: \.destination.documentTypeForm)
        ) { store in
            DocumentTypeFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            if store.canCreate {
                Button(action: {
                    send(.createDocumentTypeButtonTapped)
                }) {
                    Label(.createDocumentType, systemImage: "plus")
                }
            }
        }
    }

    public init(store: StoreOf<DocumentTypeListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<DocumentTypeListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.documentTypes.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "document.badge.gearshape",
                    title: .noDocumentTypesFound
                ) {
                    // No call to action for someone who cannot create document types: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.canCreate {
                        Button {
                            send(.createDocumentTypeButtonTapped)
                        } label: {
                            Label(.createDocumentType, systemImage: "plus.circle")
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
    DocumentTypeListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentTypeListReducer()
            }
        )
    )
}
