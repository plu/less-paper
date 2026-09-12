import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
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
                            fileTasksButton
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
        _failedFileTaskCount = Shared(.failedFileTaskCount(store.server))
    }

    @ViewBuilder
    private var selectActionsMenu: some View {
        Button {
            send(.toggleSelectionModeButtonTapped)
        } label: {
            Label(.done, systemImage: "xmark")
        }
    }

    @Shared
    private var failedFileTaskCount: Int

    // A button whose only possible outcome is a 403 is worse than no button, so it is hidden
    // entirely rather than shown disabled.
    @ViewBuilder
    private var fileTasksButton: some View {
        if store.permissions.can(.viewPaperlessTask) {
            Button {
                send(.fileTasksButtonTapped)
            } label: {
                // An HStack rather than a badge overlay on the icon: an overlay on a toolbar item is
                // clipped by the navigation bar on some heights, and this cannot be.
                HStack(spacing: .x1) {
                    Image(systemName: "tray.and.arrow.down")
                    if failedFileTaskCount > 0 {
                        Text(verbatim: String(failedFileTaskCount))
                            .capsule(
                                backgroundColor: .m3ErrorContainer,
                                font: .caption2,
                                foregroundColor: .m3OnErrorContainer,
                                padding: .init(top: .x1, leading: .x2, bottom: .x1, trailing: .x2)
                            )
                    }
                }
            }
            .accessibilityLabel(.fileTasks)
            .accessibilityValue(
                failedFileTaskCount > 0
                    ? String(localized: .failedFileTaskCount(failedFileTaskCount))
                    : ""
            )
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
