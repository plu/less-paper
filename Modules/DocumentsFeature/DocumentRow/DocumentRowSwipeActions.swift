import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

extension View {

    func documentSwipeActions(
        edges: DocumentSwipeActionSettings.Edges,
        isSelecting: Bool,
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        let leading = DocumentSwipeActionPlan(
            configured: edges.leading,
            canDelete: store.canDelete,
            canEdit: store.canEdit,
            canViewNotes: store.canViewNotes,
            hasInboxTags: !store.inboxTags.isEmpty,
            isSelecting: isSelecting
        )
        let trailing = DocumentSwipeActionPlan(
            configured: edges.trailing,
            canDelete: store.canDelete,
            canEdit: store.canEdit,
            canViewNotes: store.canViewNotes,
            hasInboxTags: !store.inboxTags.isEmpty,
            isSelecting: isSelecting
        )

        return swipeActions(edge: .leading, allowsFullSwipe: leading.allowsFullSwipe) {
            documentSwipeButtons(for: leading, store: store)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: trailing.allowsFullSwipe) {
            documentSwipeButtons(for: trailing, store: store)
        }
    }

    // Never `role: .destructive`, Delete included: it removes the row the moment the button is
    // tapped, before the confirmation has been answered - the trap TrashRowView documents.
    @ViewBuilder
    private func documentSwipeButtons(
        for plan: DocumentSwipeActionPlan,
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        ForEach(plan.actions, id: \.self) { action in
            Button {
                store.send(.view(action.rowAction))
            } label: {
                Image(systemName: action.swipeImage(isFavorited: store.isFavorited))
            }
            .accessibilityLabel(action.swipeLabel(isFavorited: store.isFavorited))
            .disabled(store.isBusy)
            .tint(action.isDestructive ? .m3Error : .m3Primary)
        }
    }
}

private extension DocumentSwipeAction {

    var rowAction: DocumentRowReducer.Action.View {
        switch self {
        case .clearInboxTags:
            .clearInboxTagsButtonTapped
        case .delete:
            .deleteButtonTapped
        case .edit:
            .editButtonTapped
        case .favorite:
            .favoriteButtonTapped
        case .openNotes:
            .notesButtonTapped
        case .preview:
            .previewButtonTapped
        case .share:
            .shareButtonTapped
        }
    }

    // Favorite is the one action whose button reports state rather than naming itself, the same way
    // the context menu's does: on a document already favorited it has to read as the undo.
    func swipeImage(isFavorited: Bool) -> String {
        guard self == .favorite, isFavorited else {
            return systemImage
        }
        return "heart.slash"
    }

    func swipeLabel(isFavorited: Bool) -> LocalizedStringResource {
        guard self == .favorite, isFavorited else {
            return localized
        }
        return .unfavorite
    }
}
