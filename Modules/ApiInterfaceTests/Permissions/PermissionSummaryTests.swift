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

    // The raw value is the wire format and splits at the FIRST underscore only: add_documenttype is
    // one word, but global_statistics would split into "global" + "statistics" if the split ran
    // from the right.
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
