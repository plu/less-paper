import Components
import Foundation

struct DocumentSwipeActionPlan: Equatable {
    let actions: [DocumentSwipeAction]
    let allowsFullSwipe: Bool
}

extension DocumentSwipeActionPlan {

    init(
        configured: [DocumentSwipeAction],
        canDelete: Bool,
        canEdit: Bool,
        canViewNotes: Bool,
        hasInboxTags: Bool,
        isSelecting: Bool
    ) {
        // Nothing swipes during a selection: the row already carries its own tap gesture and a
        // checkmark, and a swipe on top of that is two ways to mean different things at once.
        guard !isSelecting else {
            self.init(actions: [], allowsFullSwipe: false)
            return
        }

        let actions = configured.filter { action in
            switch action {
            case .clearInboxTags:
                // The edit permission as well as the tags: clearing them is a modify_tags bulk
                // edit, which the server refuses without change_document.
                canEdit && hasInboxTags
            case .delete:
                canDelete
            case .edit:
                canEdit
            case .openNotes:
                canViewNotes
            case .favorite, .preview, .share:
                true
            }
        }

        self.init(
            actions: actions,
            // A full swipe fires the first action only, so it is the first one that decides. An
            // empty edge reads false here, which is what stops it swiping open onto nothing.
            allowsFullSwipe: actions.first.map { !$0.isDestructive } ?? false
        )
    }
}
