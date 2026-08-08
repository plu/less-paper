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
            Button {} label: {
                Label(.editCorrespondent, systemImage: "person")
            }

            Button {} label: {
                Label(.editDocumentType, systemImage: "document.badge.gearshape")
            }

            Button {} label: {
                Label(.editStoragePath, systemImage: "folder")
            }

            Button {} label: {
                Label(.editTags, systemImage: "tag")
            }
        }
        .font(.title3)
        .padding(.horizontal, .x4)
    }

    @discardableResult
    private func send(_ action: DocumentListReducer.Action.View) -> StoreTask {
        viewAction(action)
    }

    private let store: StoreOf<DocumentListReducer>
    private let viewAction: (DocumentListReducer.Action.View) -> StoreTask
}
