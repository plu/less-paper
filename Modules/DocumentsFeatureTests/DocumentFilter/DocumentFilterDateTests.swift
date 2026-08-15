@testable import ApiInterface
@testable import DocumentsFeature

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentFilterDateTests {

    // MARK: - Parsing

    @Test
    func parsesModernInclusiveCreatedBounds() async throws {
        let input = makeInput([
            .init(ruleType: .createdFrom, value: "2026-01-01"),
            .init(ruleType: .createdTo, value: "2026-12-31"),
        ])

        #expect(input.date.type == .created)
        #expect(input.date.from.date == date("2026-01-01"))
        #expect(input.date.to.date == date("2026-12-31"))
    }

    @Test
    func parsesLegacyExclusiveCreatedBounds() async throws {
        let input = makeInput([
            .init(ruleType: .createdAfter, value: "2026-01-01"),
            .init(ruleType: .createdBefore, value: "2026-12-31"),
        ])

        #expect(input.date.type == .created)
        #expect(input.date.from.ruleType == .createdAfter)
        #expect(input.date.to.ruleType == .createdBefore)
    }

    @Test
    func parsesAddedBoundsWhenThereAreNoCreatedRules() async throws {
        let input = makeInput([.init(ruleType: .addedFrom, value: "2026-01-01")])

        #expect(input.date.type == .added)
        #expect(input.date.from.date == date("2026-01-01"))
    }

    @Test
    func createdWinsAndAddedPassesThroughWhenBothArePresent() async throws {
        let input = makeInput([
            .init(ruleType: .createdFrom, value: "2026-01-01"),
            .init(ruleType: .addedFrom, value: "2025-01-01"),
        ])

        #expect(input.date.type == .created)
        #expect(input.date.from.date == date("2026-01-01"))
        expectNoDifference(
            input.unsupportedFilterRules,
            [.init(ruleType: .addedFrom, value: "2025-01-01")]
        )
    }

    @Test
    func createdYearIsNotTreatedAsABound() async throws {
        let original = [FilterRule(ruleType: .createdYear, value: "2026")]
        let input = makeInput(original)

        #expect(input.date.from.date == nil)
        #expect(input.date.to.date == nil)
        expectNoDifference(input.filterRules, original)
    }

    @Test
    func unparseableDateValuePassesThrough() async throws {
        let original = [FilterRule(ruleType: .createdFrom, value: "not-a-date")]
        let input = makeInput(original)

        #expect(input.date.from.date == nil)
        expectNoDifference(input.filterRules, original)
    }

    // MARK: - Emitting

    @Test
    func emitsModernInclusiveRulesForBoundsTheUserSet() async throws {
        var input = DocumentFilterInput()
        input.date.type = .created
        input.date.from.date = date("2026-01-01")
        input.date.to.date = date("2026-12-31")

        expectNoDifference(input.filterRules, [
            .init(ruleType: .createdFrom, value: "2026-01-01"),
            .init(ruleType: .createdTo, value: "2026-12-31"),
        ])
    }

    @Test
    func emitsAddedRulesWhenTheFieldIsAdded() async throws {
        var input = DocumentFilterInput()
        input.date.type = .added
        input.date.from.date = date("2026-01-01")

        expectNoDifference(input.filterRules, [
            .init(ruleType: .addedFrom, value: "2026-01-01")
        ])
    }

    @Test
    func rememberedRuleFromTheOtherDateIsIgnored() async throws {
        var input = DocumentFilterInput()
        input.date.type = .added
        input.date.from = .init(date: date("2026-01-01"), ruleType: .createdAfter)

        expectNoDifference(input.filterRules, [
            .init(ruleType: .addedFrom, value: "2026-01-01")
        ])
    }

    // MARK: - Round trip

    @Test(arguments: [
        FilterRuleType.createdFrom,
        .createdTo,
        .createdAfter,
        .createdBefore,
        .addedFrom,
        .addedTo,
        .addedAfter,
        .addedBefore,
    ])
    func eachSpellingSurvivesARoundTrip(ruleType: FilterRuleType) async throws {
        let original = [FilterRule(ruleType: ruleType, value: "2026-06-15")]

        expectNoDifference(makeInput(original).filterRules, original)
    }

    @Test
    func aFullRangeSurvivesARoundTrip() async throws {
        let original = [
            FilterRule(ruleType: .createdAfter, value: "2026-01-01"),
            FilterRule(ruleType: .createdBefore, value: "2026-12-31"),
        ]

        expectNoDifference(makeInput(original).filterRules, original)
    }

    // MARK: - Helpers

    private func makeInput(_ filterRules: [FilterRule]) -> DocumentFilterInput {
        DocumentFilterInput(
            filterRules: filterRules,
            server: .testValue(),
            sortDirection: .descending,
            sortField: .added
        )
    }

    private func date(_ value: String) -> Date? {
        DateFormatter.filterRule.date(from: value)
    }
}
