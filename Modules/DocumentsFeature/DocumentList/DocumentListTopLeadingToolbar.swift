import ComposableArchitecture
import SwiftUI

extension View {

    func documentListTopLeadingToolbar(
        store: StoreOf<DocumentListReducer>,
        type: DocumentListToolbarType,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) -> some View {
        modifier(
            DocumentListTopLeadingToolbar(
                store: store,
                type: type,
                viewAction: viewAction
            )
        )
    }
}

private struct DocumentListTopLeadingToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.documentSelection.isActive {
                        selectActionsMenu
                    } else {
                        switch type {
                        case .inbox:
                            EmptyView()
                        case .documents:
                            defaultActionsMenu
                        }
                    }
                }
            }
    }

    init(
        store: StoreOf<DocumentListReducer>,
        type: DocumentListToolbarType,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) {
        self.store = store
        self.type = type
        self.viewAction = viewAction
    }

    @ViewBuilder
    private var selectActionsMenu: some View {
        Button {
            send(.toggleSelectionModeButtonTapped)
        } label: {
            Label(.done, systemImage: "xmark")
        }
    }

    @ViewBuilder
    private var defaultActionsMenu: some View {
        HStack {
            Button {
                send(.filterButtonTapped)
            } label: {
                Label(.filter, systemImage: "magnifyingglass")
            }
            Menu {
                Button {
                    send(.allDocumentsButtonTapped)
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: store.filter.savedView == nil ? "checkmark.circle.fill" : "circle")
                        Text(.allDocuments)
                    }
                }
                Divider()
                ForEach(store.savedViews) { savedView in
                    Button {
                        send(.savedViewButtonTapped(savedView))
                    } label: {
                        HStack(spacing: .x4) {
                            Image(systemName: store.filter.savedView?.id == savedView.id ? "checkmark.circle.fill" : "circle")
                            Text(savedView.name)
                        }
                    }
                }
            } label: {
                Label(.savedViews, systemImage: "line.3.horizontal.decrease")
            }
        }
    }

    @discardableResult
    private func send(_ action: DocumentListReducer.Action.View) -> StoreTask {
        viewAction(action)
    }

    private let store: StoreOf<DocumentListReducer>
    private let type: DocumentListToolbarType
    private let viewAction: (DocumentListReducer.Action.View) -> StoreTask
}
