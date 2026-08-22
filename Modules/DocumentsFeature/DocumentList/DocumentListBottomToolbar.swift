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
                    state: \.destination?.bulkEditMerge,
                    action: \.destination.bulkEditMerge
                )
            ) { store in
                DocumentBulkEditMergeView(store: store)
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
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditTitle,
                    action: \.destination.bulkEditTitle
                )
            ) { store in
                DocumentBulkEditTitleView(store: store)
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

            // Delete is destructive, so it sits behind an overflow menu rather than one mistap
            // away from four reversible actions. Edit title joins it for a duller reason: a sixth
            // icon does not fit — six span 411pt on a 402pt iPhone 17 Pro, clipping at both ends.
            Menu {
                Button {
                    send(.editTitleButtonTapped)
                } label: {
                    Label(.editTitle, systemImage: "textformat")
                }

                Button {
                    send(.mergeSelectedButtonTapped)
                } label: {
                    Label(.mergeDocuments, systemImage: "arrow.trianglehead.merge")
                }
                .disabled(store.documentSelection.selectedDocuments.count < 2)

                Divider()

                Button(role: .destructive) {
                    send(.deleteSelectedButtonTapped)
                } label: {
                    Label(.deleteDocuments, systemImage: "trash")
                }
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
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
