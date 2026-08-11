import ApiInterface
import ComposableArchitecture
import SwiftUI

extension View {

    func documentListBottomToolbar(
        store: StoreOf<DocumentListReducer>,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) -> some View {
        modifier(
            DocumentListBottomToolbar(
                store: store,
                viewAction: viewAction
            )
        )
    }
}

private struct DocumentListBottomToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarVisibility(store.documentSelection.tabBarVisibility, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if store.documentSelection.isActive {
                        selectActionsMenu
                    }
                }
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditCorrespondent,
                    action: \.destination.bulkEditCorrespondent
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditDocumentType,
                    action: \.destination.bulkEditDocumentType
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditStoragePath,
                    action: \.destination.bulkEditStoragePath
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditTags,
                    action: \.destination.bulkEditTags
                )
            ) { store in
                DocumentBulkEditTagsView(store: store)
                    .presentationDetents([.sheet])
            }
    }

    init(
        store: StoreOf<DocumentListReducer>,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) {
        self.store = store
        self.viewAction = viewAction
    }

    @ViewBuilder
    private var selectActionsMenu: some View {
        HStack(spacing: .x5) {
            Button {
                send(.editCorrespondentButtonTapped)
            } label: {
                Label(.editCorrespondent, systemImage: "person")
            }

            Button {
                send(.editDocumentTypeButtonTapped)
            } label: {
                Label(.editDocumentType, systemImage: "document.badge.gearshape")
            }

            Button {
                send(.editStoragePathButtonTapped)
            } label: {
                Label(.editStoragePath, systemImage: "folder")
            }

            Button {
                send(.editTagsButtonTapped)
            } label: {
                Label(.editTags, systemImage: "tag")
            }
        }
        .disabled(store.documentSelection.selectedDocuments.isEmpty)
        .font(.title3)
        .padding(.horizontal, .x4)
    }

    @discardableResult
    private func send(_ action: DocumentListReducer.Action.View) -> StoreTask {
        viewAction(action)
    }

    @Bindable
    private var store: StoreOf<DocumentListReducer>

    private let viewAction: (DocumentListReducer.Action.View) -> StoreTask
}
