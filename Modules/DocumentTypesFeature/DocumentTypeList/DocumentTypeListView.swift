import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentTypeListReducer.self)
public struct DocumentTypeListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleDocumentTypes.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleDocumentTypes, action: \.documentTypes))) { store in
                DocumentTypeRowView(store: store)
            }
        }
        .overlay(emptyListView())
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
