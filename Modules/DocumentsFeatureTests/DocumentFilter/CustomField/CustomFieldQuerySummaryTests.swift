@testable import DocumentsFeature

import ApiInterface
import CustomDump
import Foundation
import IdentifiedCollections
import Testing

@Suite
struct CustomFieldQuerySummaryTests {

    private let fields: IdentifiedArrayOf<CustomField> = [
        .testValue(dataType: .monetary, id: 1, name: "Invoice total"),
        .testValue(
            dataType: .select,
            extraData: .init(selectOptions: [
                .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
                .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
            ]),
            id: 2,
            name: "Status"
        ),
        .testValue(dataType: .boolean, id: 3, name: "Paid"),
        .testValue(dataType: .date, id: 4, name: "Due date"),
        .testValue(dataType: .documentLink, id: 6, name: "Link")
    ]

    @Test
    func comparisonOperatorsRenderAsSymbols() {
        let query = CustomFieldQuery.atom(.init(field: 1, op: .gt, value: .number(100)))
        expectNoDifference(query.summary(fields: fields), "Invoice total > 100")
    }

    @Test
    func wholeNumbersDropTheirDecimalPoint() {
        let query = CustomFieldQuery.atom(.init(field: 1, op: .lte, value: .number(12)))
        expectNoDifference(query.summary(fields: fields), "Invoice total ≤ 12")
    }

    @Test
    func selectValuesResolveToTheirOptionLabel() {
        let query = CustomFieldQuery.atom(.init(field: 2, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))
        expectNoDifference(query.summary(fields: fields), "Status = Open")
    }

    @Test
    func selectSubsetsJoinTheirLabels() {
        let query = CustomFieldQuery.atom(.init(
            field: 2,
            op: .in,
            value: .array([.string("aqgT3m4XZw8aw3Ou"), .string("MOddUdj2nhfCEsqp")])
        ))
        expectNoDifference(query.summary(fields: fields), "Status in Open, Closed")
    }

    @Test
    func existsReadsAsAPhraseRatherThanAnOperatorAndAValue() {
        expectNoDifference(
            CustomFieldQuery.atom(.init(field: 3, op: .exists, value: .bool(true))).summary(fields: fields),
            "Paid exists"
        )
        expectNoDifference(
            CustomFieldQuery.atom(.init(field: 3, op: .exists, value: .bool(false))).summary(fields: fields),
            "Paid does not exist"
        )
    }

    @Test
    func isNullReadsAsAPhrase() {
        expectNoDifference(
            CustomFieldQuery.atom(.init(field: 3, op: .isnull, value: .bool(true))).summary(fields: fields),
            "Paid is empty"
        )
        expectNoDifference(
            CustomFieldQuery.atom(.init(field: 3, op: .isnull, value: .bool(false))).summary(fields: fields),
            "Paid is not empty"
        )
    }

    @Test
    func groupsJoinWithTheirLogicalOperator() {
        let query = CustomFieldQuery.group(.and, [
            .atom(.init(field: 1, op: .gt, value: .number(100))),
            .atom(.init(field: 3, op: .exists, value: .bool(true)))
        ])
        expectNoDifference(query.summary(fields: fields), "Invoice total > 100 and Paid exists")
    }

    @Test
    func nestedGroupsAreParenthesised() {
        let query = CustomFieldQuery.group(.and, [
            .atom(.init(field: 1, op: .gt, value: .number(100))),
            .group(.or, [
                .atom(.init(field: 3, op: .exists, value: .bool(true))),
                .atom(.init(field: 4, op: .gte, value: .string("2026-09-01")))
            ])
        ])
        expectNoDifference(
            query.summary(fields: fields),
            "Invoice total > 100 and (Paid exists or Due date ≥ 2026-09-01)"
        )
    }

    @Test
    func negationIsPrefixed() {
        let query = CustomFieldQuery.negation(.atom(.init(field: 3, op: .exists, value: .bool(true))))
        expectNoDifference(query.summary(fields: fields), "not (Paid exists)")
    }

    // A saved view can outlive the field it names. Rendering the id keeps the condition visible
    // instead of silently dropping it.
    @Test
    func anUnknownFieldIsNamedByItsId() {
        let query = CustomFieldQuery.atom(.init(field: 999, op: .exists, value: .bool(true)))
        expectNoDifference(query.summary(fields: fields), "Unknown field (999) exists")
    }

    // Document ids mean nothing to a reader, and resolving titles here would mean the filter
    // sheet could not render until they loaded.
    @Test
    func aDocumentLinkConditionSummarisesAsACount() {
        let query = CustomFieldQuery.atom(.init(field: 6, op: .contains, value: .array([.number(10), .number(11)])))

        expectNoDifference(query.summary(fields: fields), "Link contains 2 documents")
    }

    @Test
    func aSingleLinkedDocumentReadsInTheSingular() {
        let query = CustomFieldQuery.atom(.init(field: 6, op: .contains, value: .array([.number(10)])))

        expectNoDifference(query.summary(fields: fields), "Link contains 1 document")
    }

    @Test
    func anEmptyGroupSummarisesAsEmptyText() {
        expectNoDifference(CustomFieldQuery.group(.and, []).summary(fields: fields), "")
    }
}
