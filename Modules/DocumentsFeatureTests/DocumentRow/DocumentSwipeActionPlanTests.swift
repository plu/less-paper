@testable import DocumentsFeature

import Components
import Testing

@Suite
struct DocumentSwipeActionPlanTests {

    @Test
    func keepsConfiguredOrder() async throws {
        let plan = makePlan(configured: [.share, .edit])

        #expect(plan.actions == [.share, .edit])
        #expect(plan.allowsFullSwipe)
    }

    @Test
    func dropsActionsThisUserMayNotPerform() async throws {
        let plan = makePlan(configured: [.edit, .delete], canDelete: false, canEdit: false)

        #expect(plan.actions.isEmpty)
    }

    @Test
    func dropsOpenNotesWithoutThePermission() async throws {
        let plan = makePlan(configured: [.openNotes, .preview], canViewNotes: false)

        #expect(plan.actions == [.preview])
    }

    // Otherwise the swipe reports having cleared tags it never touched.
    @Test
    func dropsClearInboxTagsWhenTheDocumentHasNone() async throws {
        let plan = makePlan(configured: [.clearInboxTags, .share], hasInboxTags: false)

        #expect(plan.actions == [.share])
    }

    // An empty tray reads as a bug; a dead edge reads as "nothing here".
    @Test
    func anEdgeWhoseActionsAreAllHiddenIsEmptyAndDoesNotFullSwipe() async throws {
        let plan = makePlan(configured: [.clearInboxTags], hasInboxTags: false)

        #expect(plan.actions.isEmpty)
        #expect(!plan.allowsFullSwipe)
    }

    @Test
    func aDestructiveFirstActionSuppressesTheFullSwipe() async throws {
        let plan = makePlan(configured: [.delete, .share])

        #expect(plan.actions == [.delete, .share])
        #expect(!plan.allowsFullSwipe)
    }

    // Delete behind a non-destructive action is safe: a full swipe fires only the first.
    @Test
    func aDestructiveSecondActionLeavesTheFullSwipeAlone() async throws {
        let plan = makePlan(configured: [.share, .delete])

        #expect(plan.allowsFullSwipe)
    }

    @Test
    func selectionModeSuppressesEverything() async throws {
        let plan = makePlan(configured: [.edit, .share], isSelecting: true)

        #expect(plan.actions.isEmpty)
        #expect(!plan.allowsFullSwipe)
    }

    private func makePlan(
        configured: [DocumentSwipeAction],
        canDelete: Bool = true,
        canEdit: Bool = true,
        canViewNotes: Bool = true,
        hasInboxTags: Bool = true,
        isSelecting: Bool = false
    ) -> DocumentSwipeActionPlan {
        DocumentSwipeActionPlan(
            configured: configured,
            canDelete: canDelete,
            canEdit: canEdit,
            canViewNotes: canViewNotes,
            hasInboxTags: hasInboxTags,
            isSelecting: isSelecting
        )
    }
}
