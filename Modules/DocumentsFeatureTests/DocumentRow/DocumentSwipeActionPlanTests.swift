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

    // Clearing inbox tags is a modify_tags bulk edit, which this codebase gates on change_document
    // everywhere else - DocumentSelectionReducer's canBulkEdit is the same check. Without this a
    // read-only user is offered the default inbox swipe and gets a 403 for it.
    @Test
    func dropsClearInboxTagsWithoutTheEditPermission() async throws {
        let plan = makePlan(configured: [.clearInboxTags, .preview], canEdit: false)

        #expect(plan.actions == [.preview])
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

    // Clearing inbox tags is prepended by the renderer on the trailing edge, never configured, so
    // it has to come first and own the full swipe even when the user put something else there.
    @Test
    func aPrependedActionComesFirstAndTakesTheFullSwipe() async throws {
        let plan = makePlan(configured: [.share], prepending: [.clearInboxTags])

        #expect(plan.actions == [.clearInboxTags, .share])
        #expect(plan.allowsFullSwipe)
    }

    @Test
    func aPrependedActionThatDoesNotApplyIsLeftOut() async throws {
        let plan = makePlan(
            configured: [.share],
            prepending: [.clearInboxTags],
            hasInboxTags: false
        )

        #expect(plan.actions == [.share])
    }

    // The cap is about how many buttons a person can read mid-gesture, so an action the app added
    // on their behalf does not get to raise it.
    @Test
    func aPrependedActionTruncatesRatherThanExceedingTheCap() async throws {
        let plan = makePlan(configured: [.share, .edit], prepending: [.clearInboxTags])

        #expect(plan.actions == [.clearInboxTags, .share])
    }

    @Test
    func aPrependedActionIsNotRepeatedWhenAlsoConfigured() async throws {
        let plan = makePlan(configured: [.favorite, .share], prepending: [.favorite])

        #expect(plan.actions == [.favorite, .share])
    }

    private func makePlan(
        configured: [DocumentSwipeAction],
        prepending: [DocumentSwipeAction] = [],
        canDelete: Bool = true,
        canEdit: Bool = true,
        canViewNotes: Bool = true,
        hasInboxTags: Bool = true,
        isSelecting: Bool = false
    ) -> DocumentSwipeActionPlan {
        DocumentSwipeActionPlan(
            configured: configured,
            prepending: prepending,
            canDelete: canDelete,
            canEdit: canEdit,
            canViewNotes: canViewNotes,
            hasInboxTags: hasInboxTags,
            isSelecting: isSelecting
        )
    }
}
