@testable import ApiInterface

import Testing

@Suite
struct PermissionSummaryTests {

    @Test
    func groupsByTypeAndSortsByTypeName() {
        let summaries = PermissionSummary.grouped([
            .viewTag,
            .addTag,
            .viewCorrespondent,
        ])

        #expect(summaries.map(\.type) == ["correspondent", "tag"])
        #expect(summaries[0].actions == ["view"])
        // Sorted so the same set always reads the same way, rather than in enum declaration order.
        #expect(summaries[1].actions == ["add", "view"])
    }

    // What this actually covers: a codename whose type half is a single word carrying no separator
    // of its own - add_documenttype, change_customfield - is grouped under that whole word rather
    // than mangled. It does NOT exercise maxSplits: 1, and cannot: every one of Permission's cases
    // has exactly one underscore, so deleting the limit would leave this assertion identical.
    //
    // The limit is still right, and it is not defensive about a hypothetical. The live server sends
    // view_global_statistics and view_system_monitoring in ui_settings. The app does not model them
    // yet, so nothing here reaches PermissionSummary - but the day a case is added for either,
    // split without the limit returns three parts and PermissionSummary.grouped's
    // `guard parts.count == 2` drops the permission silently. Nothing would go red; the row would
    // simply not be there.
    @Test
    func splitsAtTheFirstUnderscoreOnly() {
        let summaries = PermissionSummary.grouped([.addDocumentType, .changeCustomfield])

        #expect(summaries.map(\.type) == ["customfield", "documenttype"])
    }

    @Test
    func emptyInputProducesNoSummaries() {
        #expect(PermissionSummary.grouped([]).isEmpty)
    }
}
