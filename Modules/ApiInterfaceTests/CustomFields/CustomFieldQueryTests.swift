@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct CustomFieldQueryTests {

    @Test
    func decodeBareAtomAtTopLevel() throws {
        let query = try #require(CustomFieldQuery(json: #"[7,"exists",true]"#))
        expectNoDifference(query, .atom(.init(field: 7, op: .exists, value: .bool(true))))
    }

    @Test
    func encodeGroup() {
        let query = CustomFieldQuery.group(.and, [.atom(.init(field: 7, op: .exists, value: .bool(true)))])
        expectNoDifference(query.json, #"["AND",[[7,"exists",true]]]"#)
    }

    // The server returns 400 for `["NOT",[child]]` and 500 for `["NOT",[a,b]]`, so NOT serializes
    // its single child inline. Verified against paperless-ngx 3.0.5.
    @Test
    func encodeNegationWithChildInline() {
        let query = CustomFieldQuery.negation(.atom(.init(field: 7, op: .exists, value: .bool(true))))
        expectNoDifference(query.json, #"["NOT",[7,"exists",true]]"#)
    }

    @Test
    func encodeNegationOfGroup() {
        let query = CustomFieldQuery.negation(.group(.and, [.atom(.init(field: 7, op: .exists, value: .bool(true)))]))
        expectNoDifference(query.json, #"["NOT",["AND",[[7,"exists",true]]]]"#)
    }

    @Test
    func decodeNegationWithChildInline() throws {
        let query = try #require(CustomFieldQuery(json: #"["NOT",[7,"exists",true]]"#))
        expectNoDifference(query, .negation(.atom(.init(field: 7, op: .exists, value: .bool(true)))))
    }

    // A query hand-written elsewhere may use the shape the server rejects. Normalising it on the
    // way in is free and means such a saved view still opens.
    @Test
    func decodeNegationWrappedInASingleElementList() throws {
        let query = try #require(CustomFieldQuery(json: #"["NOT",[[7,"exists",true]]]"#))
        expectNoDifference(query, .negation(.atom(.init(field: 7, op: .exists, value: .bool(true)))))
    }

    @Test
    func roundTripNestedQuery() throws {
        let json = #"["AND",[[7,"icontains","a"],["OR",[[8,"gt",5],["NOT",[9,"exists",true]]]]]]"#
        let query = try #require(CustomFieldQuery(json: json))
        expectNoDifference(query.json, json)
    }

    @Test(arguments: [
        "notjson",
        #"["XOR",[[7,"exists",true]]]"#,
        #"[7,"nope",true]"#,
        #"["AND","nope"]"#,
        "{}",
    ])
    func decodeInvalidReturnsNil(json: String) {
        #expect(CustomFieldQuery(json: json) == nil)
    }

    @Test
    func encodeWholeNumbersWithoutADecimalPoint() {
        let query = CustomFieldQuery.group(.and, [.atom(.init(field: 8, op: .gt, value: .number(5)))])
        expectNoDifference(query.json, #"["AND",[[8,"gt",5]]]"#)
    }

    @Test
    func encodeFractionalNumbers() {
        let query = CustomFieldQuery.group(.and, [.atom(.init(field: 8, op: .gt, value: .number(5.5)))])
        expectNoDifference(query.json, #"["AND",[[8,"gt",5.5]]]"#)
    }

    @Test
    func encodeArrayValues() {
        let query = CustomFieldQuery.group(.and, [
            .atom(.init(field: 6, op: .in, value: .array([.string("jmdLfBGNOfk8vGsc")])))
        ])
        expectNoDifference(query.json, #"["AND",[[6,"in",["jmdLfBGNOfk8vGsc"]]]]"#)
    }

    @Test
    func encodeStringValuesWithoutEscapingSlashes() {
        let query = CustomFieldQuery.atom(.init(field: 7, op: .icontains, value: .string("a/b")))
        expectNoDifference(query.json, #"[7,"icontains","a/b"]"#)
    }

    @Test
    func decodeOrGroup() throws {
        let query = try #require(CustomFieldQuery(json: #"["OR",[[7,"icontains","a"],[8,"gt",5]]]"#))
        expectNoDifference(query, .group(.or, [
            .atom(.init(field: 7, op: .icontains, value: .string("a"))),
            .atom(.init(field: 8, op: .gt, value: .number(5)))
        ]))
    }

    @Test
    func logicalOperatorRawValuesAreUppercase() {
        expectNoDifference(CustomFieldQueryLogicalOperator.allCases.map(\.rawValue), ["AND", "OR"])
    }
}

@Suite
struct CustomFieldQueryIntrospectionTests {

    @Test
    func atomCountAndDepth() throws {
        let query = try #require(CustomFieldQuery(json: #"["AND",[[7,"exists",true],["OR",[[8,"gt",5]]]]]"#))
        #expect(query.atomCount == 2)
        #expect(query.depth == 3)
    }

    @Test
    func bareAtomHasDepthOne() {
        let query = CustomFieldQuery.atom(.init(field: 7, op: .exists, value: .bool(true)))
        #expect(query.depth == 1)
        #expect(query.atomCount == 1)
    }

    @Test
    func negationAddsOneLevelToItsChild() throws {
        let query = try #require(CustomFieldQuery(json: #"["NOT",[7,"exists",true]]"#))
        #expect(query.depth == 2)
        #expect(query.atomCount == 1)
    }

    @Test
    func emptyGroupHasNoAtoms() {
        #expect(CustomFieldQuery.group(.and, []).atomCount == 0)
    }

    @Test
    func pruneDropsAtomsWithEmptyStringValues() {
        let query = CustomFieldQuery.group(.and, [
            .atom(.init(field: 7, op: .icontains, value: .string(""))),
            .atom(.init(field: 8, op: .gt, value: .number(5)))
        ])
        expectNoDifference(query.pruned, .group(.and, [.atom(.init(field: 8, op: .gt, value: .number(5)))]))
    }

    @Test
    func pruneDropsAtomsWithEmptyArrayValues() {
        let query = CustomFieldQuery.atom(.init(field: 6, op: .in, value: .array([])))
        #expect(query.pruned == nil)
    }

    @Test
    func pruneDropsGroupsLeftEmpty() {
        let query = CustomFieldQuery.group(.and, [
            .group(.or, [.atom(.init(field: 7, op: .icontains, value: .string("")))])
        ])
        #expect(query.pruned == nil)
    }

    @Test
    func pruneDropsAnEmptyGroup() {
        #expect(CustomFieldQuery.group(.and, []).pruned == nil)
    }

    @Test
    func pruneDropsANegationLeftEmpty() {
        let query = CustomFieldQuery.negation(.atom(.init(field: 7, op: .icontains, value: .string(""))))
        #expect(query.pruned == nil)
    }

    // `exists=false` is a meaningful condition, not an unfilled one.
    @Test
    func pruneKeepsBooleanFalse() {
        let query = CustomFieldQuery.atom(.init(field: 7, op: .exists, value: .bool(false)))
        expectNoDifference(query.pruned, query)
    }

    @Test
    func pruneKeepsZero() {
        let query = CustomFieldQuery.atom(.init(field: 8, op: .gt, value: .number(0)))
        expectNoDifference(query.pruned, query)
    }

    @Test
    func pruneDropsAtomsWhoseValueKindDoesNotMatchTheirOperator() {
        // A field swapped from string to integer leaves `icontains` holding a number until the
        // editor resets it; sending that is the 400 the server gives for a type mismatch.
        let query = CustomFieldQuery.atom(.init(field: 7, op: .icontains, value: .bool(true)))
        #expect(query.pruned == nil)
    }

    @Test
    func limitsMatchTheWebClient() {
        #expect(CustomFieldQuery.maximumAtoms == 5)
        #expect(CustomFieldQuery.maximumDepth == 4)
    }
}

@Suite
struct CustomFieldQueryPathTests {

    private let query = CustomFieldQuery.group(.and, [
        .atom(.init(field: 1, op: .exists, value: .bool(true))),
        .group(.or, [
            .atom(.init(field: 2, op: .exists, value: .bool(true))),
            .negation(.atom(.init(field: 3, op: .exists, value: .bool(true))))
        ])
    ])

    @Test
    func theEmptyPathAddressesTheRoot() {
        expectNoDifference(query[[]], query)
    }

    @Test
    func aPathAddressesANestedAtom() {
        expectNoDifference(query[[1, 0]], .atom(.init(field: 2, op: .exists, value: .bool(true))))
    }

    @Test
    func aNegationsOnlyChildIsAtIndexZero() {
        expectNoDifference(query[[1, 1, 0]], .atom(.init(field: 3, op: .exists, value: .bool(true))))
    }

    @Test
    func anOutOfRangePathAddressesNothing() {
        #expect(query[[9]] == nil)
        #expect(query[[0, 0]] == nil)
    }

    @Test
    func assigningReplacesANestedNode() {
        var query = query
        query[[1, 0]] = .atom(.init(field: 4, op: .isnull, value: .bool(false)))

        expectNoDifference(query[[1, 0]], .atom(.init(field: 4, op: .isnull, value: .bool(false))))
        expectNoDifference(query[[0]], .atom(.init(field: 1, op: .exists, value: .bool(true))))
    }

    @Test
    func appendingAddsToAGroup() {
        var query = query
        query.append(.atom(.init(field: 5, op: .exists, value: .bool(true))), to: [1])

        #expect(query[[1]]?.children?.count == 3)
        expectNoDifference(query[[1, 2]], .atom(.init(field: 5, op: .exists, value: .bool(true))))
    }

    @Test
    func appendingToAnAtomDoesNothing() {
        var query = query
        query.append(.atom(.init(field: 5, op: .exists, value: .bool(true))), to: [0])

        expectNoDifference(query[[0]], .atom(.init(field: 1, op: .exists, value: .bool(true))))
    }

    @Test
    func removingDropsAChild() {
        var query = query
        query.remove(at: [0])

        #expect(query.children?.count == 1)
        #expect(query[[0]]?.children?.count == 2)
    }

    // A negation with nothing inside is not a query, so removing its child removes it too.
    @Test
    func removingANegationsChildRemovesTheNegation() {
        var query = query
        query.remove(at: [1, 1, 0])

        #expect(query[[1]]?.children?.count == 1)
        expectNoDifference(query[[1, 0]], .atom(.init(field: 2, op: .exists, value: .bool(true))))
    }

    @Test
    func removingTheRootIsANoOp() {
        var query = query
        query.remove(at: [])

        expectNoDifference(query, self.query)
    }

    @Test
    func anAtomHasNoChildren() {
        #expect(CustomFieldQuery.atom(.init(field: 1, op: .exists, value: .bool(true))).children == nil)
    }
}

@Suite
struct CustomFieldQueryAtomDefaultsTests {

    @Test
    func aNewConditionStartsOnTheFirstOperatorTheFieldAdmits() {
        let atom = CustomFieldQuery.Atom(defaultFor: .testValue(dataType: .string, id: 7))
        expectNoDifference(atom, .init(field: 7, op: .exists, value: .bool(true)))
    }

    @Test
    func aFieldOfUnknownTypeCannotSeedACondition() {
        #expect(CustomFieldQuery.Atom(defaultFor: .testValue(dataType: .unknown, id: 7)) == nil)
    }

    @Test
    func changingTheFieldKeepsAnOperatorTheNewTypeStillAdmits() {
        var atom = CustomFieldQuery.Atom(field: 7, op: .icontains, value: .string("a"))
        atom.setField(.testValue(dataType: .url, id: 8))

        expectNoDifference(atom, .init(field: 8, op: .icontains, value: .string("a")))
    }

    // A string field left on `icontains` and switched to integer would send an operator the server
    // rejects outright — "string does not support query expr" is the same class of 400.
    @Test
    func changingTheFieldResetsAnOperatorTheNewTypeRejects() {
        var atom = CustomFieldQuery.Atom(field: 7, op: .icontains, value: .string("a"))
        atom.setField(.testValue(dataType: .integer, id: 8))

        expectNoDifference(atom, .init(field: 8, op: .exists, value: .bool(true)))
    }

    @Test
    func changingTheOperatorResetsAValueOfADifferentKind() {
        var atom = CustomFieldQuery.Atom(field: 7, op: .icontains, value: .string("a"))
        atom.setOperator(.exists, field: nil)

        expectNoDifference(atom, .init(field: 7, op: .exists, value: .bool(true)))
    }

    private static let selectField = CustomField.testValue(
        dataType: .select,
        extraData: .init(selectOptions: [
            .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
            .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
        ]),
        id: 9,
        name: "Status"
    )

    // An empty string is not a value a select field can hold — the picker renders blank and warns
    // that the selection has no associated tag.
    @Test
    func switchingASelectFieldToAStringOperatorSeedsTheFirstOption() {
        var atom = CustomFieldQuery.Atom(field: 9, op: .exists, value: .bool(true))
        atom.setOperator(.exact, field: Self.selectField)

        expectNoDifference(atom, .init(field: 9, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))
    }

    @Test
    func choosingASelectFieldSeedsTheFirstOption() {
        var atom = CustomFieldQuery.Atom(field: 1, op: .exact, value: .string("free text"))
        atom.setField(Self.selectField)

        expectNoDifference(atom, .init(field: 9, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))
    }

    @Test
    func aSelectSubsetStillStartsEmpty() {
        var atom = CustomFieldQuery.Atom(field: 9, op: .exists, value: .bool(true))
        atom.setOperator(.in, field: Self.selectField)

        expectNoDifference(atom, .init(field: 9, op: .in, value: .array([])))
    }

    @Test
    func aNonSelectFieldStillStartsWithAnEmptyString() {
        var atom = CustomFieldQuery.Atom(field: 1, op: .exists, value: .bool(true))
        atom.setOperator(.icontains, field: .testValue(dataType: .string, id: 1))

        expectNoDifference(atom, .init(field: 1, op: .icontains, value: .string("")))
    }

    @Test
    func changingTheOperatorKeepsAValueOfTheSameKind() {
        var atom = CustomFieldQuery.Atom(field: 7, op: .gte, value: .string("5"))
        atom.setOperator(.lte, field: nil)

        expectNoDifference(atom, .init(field: 7, op: .lte, value: .string("5")))
    }
}

@Suite
struct CustomFieldQueryAtomFieldChangeTests {

    private static let selectField = CustomField.testValue(
        dataType: .select,
        extraData: .init(selectOptions: [
            .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
            .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
        ]),
        id: 9,
        name: "Status"
    )

    // Switching between two text fields must not throw away what the user typed.
    @Test
    func typedTextSurvivesAMoveBetweenTextFields() {
        var atom = CustomFieldQuery.Atom(field: 7, op: .icontains, value: .string("invoice"))
        atom.setField(.testValue(dataType: .url, id: 8))

        expectNoDifference(atom, .init(field: 8, op: .icontains, value: .string("invoice")))
    }

    @Test
    func anOptionIdIsReseededWhenMovingBetweenSelectFields() {
        let other = CustomField.testValue(
            dataType: .select,
            extraData: .init(selectOptions: [.init(id: "zzz", label: "Other")]),
            id: 10,
            name: "Other"
        )
        var atom = CustomFieldQuery.Atom(field: 9, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
        atom.setField(other)

        expectNoDifference(atom, .init(field: 10, op: .exact, value: .string("zzz")))
    }

    @Test
    func anOptionIdTheNewFieldAlsoHasIsKept() {
        var atom = CustomFieldQuery.Atom(field: 9, op: .exact, value: .string("MOddUdj2nhfCEsqp"))
        atom.setField(Self.selectField)

        expectNoDifference(atom, .init(field: 9, op: .exact, value: .string("MOddUdj2nhfCEsqp")))
    }
}
