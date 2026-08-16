import ComposableArchitecture
import SwiftUI

extension View {

    func documentListTopTrailingToolbar(
        store: StoreOf<DocumentListReducer>,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) -> some View {
        modifier(
            DocumentListTopTrailingToolbar(
                store: store,
                viewAction: viewAction
            )
        )
    }
}

private struct DocumentListTopTrailingToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .documentImport(
                store: store.scope(state: \.documentImport, action: \.documentImport)
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.documentSelection.isActive {
                        selectActionsMenu
                    } else {
                        defaultActionsMenu
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
    private var defaultActionsMenu: some View {
        Menu {
            Button {
                send(.importButtonTapped)
            } label: {
                Label(.import, systemImage: "doc.badge.plus")
            }

            Button {
                send(.scanButtonTapped)
            } label: {
                Label(.scan, systemImage: "camera")
            }

            Button {
                send(.toggleSelectionModeButtonTapped)
            } label: {
                Label(.select, systemImage: "checklist")
            }

            serversMenu
        } label: {
            Label(.moreActions, systemImage: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var selectActionsMenu: some View {
        Menu {
            Button {
                store.send(.documentSelection(.selectAllLoadedButtonTapped))
            } label: {
                Label(.selectAllLoaded, systemImage: "checklist")
            }
            Button {
                store.send(.documentSelection(.selectAllMatchingButtonTapped))
            } label: {
                Label(.selectAllMatching, systemImage: "checklist.checked")
            }
            Button {
                store.send(.documentSelection(.selectNoneButtonTapped))
            } label: {
                Label(.selectNone, systemImage: "checklist.unchecked")
            }
        } label: {
            Label(.select, systemImage: "checklist")
        }
    }

    @ViewBuilder
    private var serversMenu: some View {
        if store.servers.count > 1 {
            Menu {
                ForEach(store.servers.sorted()) { server in
                    Button {
                        send(.serverButtonTapped(server))
                    } label: {
                        if server == store.server {
                            Label(server.alias, systemImage: "checkmark")
                        } else {
                            Text(server.alias)
                        }
                    }
                }
            } label: {
                Label(.servers, systemImage: "server.rack")
            }
        }
    }

    @discardableResult
    private func send(_ action: DocumentListReducer.Action.View) -> StoreTask {
        viewAction(action)
    }

    private let store: StoreOf<DocumentListReducer>
    private let viewAction: (DocumentListReducer.Action.View) -> StoreTask
}
