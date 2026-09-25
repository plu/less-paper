import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

public extension View {

    // `leadingPrefix` is for an action a screen always offers whatever the user configured - the
    // Offline list puts removal there, so a full swipe right always takes the document off it.
    // Clearing inbox tags is the trailing equivalent and is not a parameter: it applies to any
    // document carrying inbox tags, on every list, so no caller gets to forget it.
    func documentSwipeActions(
        settings: DocumentSwipeActionSettings,
        isSelecting: Bool,
        leadingPrefix: [DocumentSwipeAction] = [],
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        let leading = DocumentSwipeActionPlan(
            configured: settings.leading,
            prepending: leadingPrefix,
            canDelete: store.canDelete,
            canEdit: store.canEdit,
            canViewNotes: store.canViewNotes,
            hasInboxTags: !store.inboxTags.isEmpty,
            isSelecting: isSelecting
        )
        let trailing = DocumentSwipeActionPlan(
            configured: settings.trailing,
            prepending: [.clearInboxTags],
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
    internal func documentSwipeButtons(
        for plan: DocumentSwipeActionPlan,
        store: StoreOf<DocumentRowReducer>
    ) -> some View {
        ForEach(plan.actions, id: \.self) { action in
            Button {
                store.send(.view(action.rowAction))
            } label: {
                Image(systemName: action.swipeImage(isSavedOffline: store.isSavedOffline))
            }
            .accessibilityLabel(action.swipeLabel(isSavedOffline: store.isSavedOffline))
            .disabled(store.isBusy)
            // Not m3Primary/m3Error: both invert between themes, and the system draws this
            // button's label in white regardless of what the label view asks for - so a tint that
            // goes light in dark mode puts white on mint, or white on pale pink.
            .tint(action.isDestructive ? .swipeActionDestructive : .swipeAction)
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
        case .saveOffline:
            .saveOfflineButtonTapped
        case .openNotes:
            .notesButtonTapped
        case .preview:
            .previewButtonTapped
        case .share:
            .shareButtonTapped
        }
    }

    // Saving offline is the one action whose button reports state rather than naming itself, the
    // same way the context menu's does: on a document already saved it has to read as the undo.
    func swipeImage(isSavedOffline: Bool) -> String {
        guard self == .saveOffline, isSavedOffline else {
            return systemImage
        }
        return "arrow.down.circle.fill"
    }

    func swipeLabel(isSavedOffline: Bool) -> LocalizedStringResource {
        guard self == .saveOffline, isSavedOffline else {
            return localized
        }
        return .removeFromOffline
    }
}
