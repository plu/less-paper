import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentTypeListReducer.self)
public struct DocumentTypeListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.documentTypes, action: \.documentTypes))) { store in
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
            Button(action: {
                send(.createDocumentTypeButtonTapped)
            }) {
                Label(.createDocumentType, systemImage: "plus")
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
