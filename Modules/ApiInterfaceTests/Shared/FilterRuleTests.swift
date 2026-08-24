@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct FilterRuleTests {

    @Test
    func initWithRuleTypeAndValue() async throws {
        let rule = FilterRule(ruleType: .title, value: "test")

        #expect(rule.ruleType == .title)
        #expect(rule.value == "test")
    }

    @Test
    func initWithRuleTypeAndNilValue() async throws {
        let rule = FilterRule(ruleType: .isInInbox, value: nil)

        #expect(rule.ruleType == .isInInbox)
        #expect(rule.value == nil)
    }

    @Test
    func equalityWithSameValues() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "test")
        let rule2 = FilterRule(ruleType: .title, value: "test")

        #expect(rule1 == rule2)
    }

    @Test
    func equalityWithDifferentValues() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "test1")
        let rule2 = FilterRule(ruleType: .title, value: "test2")

        #expect(rule1 != rule2)
    }

    @Test
    func equalityWithDifferentRuleTypes() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "test")
        let rule2 = FilterRule(ruleType: .content, value: "test")

        #expect(rule1 != rule2)
    }

    @Test
    func equalityWithCommaSeperatedValues() async throws {
        let rule1 = FilterRule(ruleType: .hasTagsAny, value: "1,2,3")
        let rule2 = FilterRule(ruleType: .hasTagsAny, value: "3,1,2")

        #expect(rule1 == rule2)
    }

    @Test
    func equalityWithNilValues() async throws {
        let rule1 = FilterRule(ruleType: .isInInbox, value: nil)
        let rule2 = FilterRule(ruleType: .isInInbox, value: nil)

        #expect(rule1 == rule2)
    }

    @Test
    func equalityWithOneNilValue() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "test")
        let rule2 = FilterRule(ruleType: .title, value: nil)

        #expect(rule1 != rule2)
    }

    @Test
    func compareRulesBySameRuleType() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "a")
        let rule2 = FilterRule(ruleType: .title, value: "b")

        #expect(rule1 < rule2)
    }

    @Test
    func compareRulesByDifferentRuleType() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "z")
        let rule2 = FilterRule(ruleType: .content, value: "a")

        #expect(rule1 < rule2)
    }

    @Test
    func compareRulesWithNilValues() async throws {
        let rule1 = FilterRule(ruleType: .title, value: nil)
        let rule2 = FilterRule(ruleType: .title, value: "test")

        #expect(rule1 < rule2)
    }

    @Test
    func sortRules() async throws {
        let rules = [
            FilterRule(ruleType: .content, value: "b"),
            FilterRule(ruleType: .title, value: "z"),
            FilterRule(ruleType: .title, value: "a")
        ]

        let sorted = rules.sorted()

        #expect(sorted[0] == FilterRule(ruleType: .title, value: "a"))
        #expect(sorted[1] == FilterRule(ruleType: .title, value: "z"))
        #expect(sorted[2] == FilterRule(ruleType: .content, value: "b"))
    }

    @Test
    func arrayEqualityWithSameRules() async throws {
        let array1 = [
            FilterRule(ruleType: .title, value: "test"),
            FilterRule(ruleType: .content, value: "content")
        ]
        let array2 = [
            FilterRule(ruleType: .content, value: "content"),
            FilterRule(ruleType: .title, value: "test")
        ]

        #expect(array1 == array2)
    }

    @Test
    func arrayEqualityWithDifferentRules() async throws {
        let array1 = [FilterRule(ruleType: .title, value: "test")]
        let array2 = [FilterRule(ruleType: .content, value: "test")]

        #expect(array1 != array2)
    }

    @Test
    func arrayEqualityWithDifferentCounts() async throws {
        let array1 = [FilterRule(ruleType: .title, value: "test")]
        let array2 = [
            FilterRule(ruleType: .title, value: "test"),
            FilterRule(ruleType: .content, value: "content")
        ]

        #expect(array1 != array2)
    }

    @Test
    func mergedWithNoMergeableRules() async throws {
        let rules = [
            FilterRule(ruleType: .title, value: "test"),
            FilterRule(ruleType: .content, value: "content")
        ]

        let merged = rules.merged

        expectNoDifference(merged, rules.sorted())
    }

    @Test
    func mergedWithMergeableRules() async throws {
        let rules = [
            FilterRule(ruleType: .fulltextQuery, value: "query1"),
            FilterRule(ruleType: .fulltextQuery, value: "query2"),
            FilterRule(ruleType: .title, value: "title")
        ]

        let merged = rules.merged

        let expected = [
            FilterRule(ruleType: .fulltextQuery, value: "query1,query2"),
            FilterRule(ruleType: .title, value: "title")
        ]

        expectNoDifference(merged, expected.sorted())
    }

    @Test
    func mergedWithMultipleMergeableRulesInSequence() async throws {
        let rules = [
            FilterRule(ruleType: .fulltextQuery, value: "c"),
            FilterRule(ruleType: .fulltextQuery, value: "a"),
            FilterRule(ruleType: .fulltextQuery, value: "b")
        ]

        let merged = rules.merged

        let expected = [FilterRule(ruleType: .fulltextQuery, value: "a,b,c")]

        expectNoDifference(merged, expected)
    }

    @Test
    func mergedWithNilValues() async throws {
        let rules = [
            FilterRule(ruleType: .fulltextQuery, value: nil),
            FilterRule(ruleType: .fulltextQuery, value: "query"),
            FilterRule(ruleType: .title, value: "title")
        ]

        let merged = rules.merged

        let expected = [
            FilterRule(ruleType: .fulltextQuery, value: "query"),
            FilterRule(ruleType: .title, value: "title")
        ]

        expectNoDifference(merged, expected.sorted())
    }

    @Test
    func queryDictionaryWithBasicRules() async throws {
        let rules = [
            FilterRule(ruleType: .title, value: "test"),
            FilterRule(ruleType: .content, value: "content")
        ]

        let queryDictionary = rules.queryDictionary

        let expected: [String: AnyHashable] = [
            "title__icontains": "test",
            "content__icontains": "content"
        ]

        expectNoDifference(queryDictionary, expected)
    }

    @Test
    func queryDictionaryWithNilValue() async throws {
        let rules = [
            FilterRule(ruleType: .correspondent, value: nil)
        ]

        let queryDictionary = rules.queryDictionary

        let expected: [String: AnyHashable] = [
            "correspondent__isnull": true
        ]

        expectNoDifference(queryDictionary, expected)
    }

    @Test
    func queryDictionaryWithMultipleRulesSameType() async throws {
        let rules = [
            FilterRule(ruleType: .title, value: "test1"),
            FilterRule(ruleType: .title, value: "test2")
        ]

        let queryDictionary = rules.queryDictionary

        let expected: [String: AnyHashable] = [
            "title__icontains": "test1,test2"
        ]

        expectNoDifference(queryDictionary, expected)
    }

    @Test
    func queryDictionaryWithMixedRules() async throws {
        let rules = [
            FilterRule(ruleType: .title, value: "title"),
            FilterRule(ruleType: .documentType, value: nil),
            FilterRule(ruleType: .hasTagsAny, value: "1"),
            FilterRule(ruleType: .hasTagsAny, value: "2")
        ]

        let queryDictionary = rules.queryDictionary

        let expected: [String: AnyHashable] = [
            "title__icontains": "title",
            "document_type__isnull": true,
            "tags__id__in": "1,2"
        ]

        expectNoDifference(queryDictionary, expected)
    }

    @Test
    func queryDictionaryWithRuleTypesThatDontHaveIsNull() async throws {
        let rules = [
            FilterRule(ruleType: .title, value: nil),
            FilterRule(ruleType: .content, value: nil)
        ]

        let queryDictionary = rules.queryDictionary

        let expected: [String: AnyHashable] = [:]

        expectNoDifference(queryDictionary, expected)
    }

    @Test
    func hashableConformance() async throws {
        let rule1 = FilterRule(ruleType: .title, value: "test")
        let rule2 = FilterRule(ruleType: .title, value: "test")
        let rule3 = FilterRule(ruleType: .content, value: "test")

        let set: Set<FilterRule> = [rule1, rule2, rule3]

        #expect(set.count == 2)
        #expect(set.contains(rule1))
        #expect(set.contains(rule2))
        #expect(set.contains(rule3))
    }

    @Test
    func encodeAndDecode() async throws {
        let rule = FilterRule(ruleType: .title, value: "test")

        let encoded = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(FilterRule.self, from: encoded)

        #expect(decoded == rule)
    }

    @Test
    func encodeAndDecodeWithNilValue() async throws {
        let rule = FilterRule(ruleType: .isInInbox, value: nil)

        let encoded = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(FilterRule.self, from: encoded)

        #expect(decoded == rule)
    }
}

// `FilterRule.==` compares comma-split fragments, and a custom field query's JSON value is full of
// commas. These characterize what that means for the filter sheet's unsaved-changes indicator,
// which compares a saved view's rules against the current ones.
@Suite
struct FilterRuleCustomFieldQueryEqualityTests {

    @Test
    func aQueryEqualsAnIdenticallyBuiltRule() {
        let json = #"["AND",[[7,"exact","a"],[8,"exact","b"]]]"#
        let rule = FilterRule(ruleType: .customFieldsQuery, value: json)
        let same = FilterRule(ruleType: .customFieldsQuery, value: String(json))

        #expect(rule == same)
    }

    @Test
    func swappingTwoAtomsValuesIsNotEqual() {
        #expect(FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exact","a"],[8,"exact","b"]]]"#)
            != FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exact","b"],[8,"exact","a"]]]"#))
    }

    @Test
    func changingAnOperatorIsNotEqual() {
        #expect(FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"gt",5]]]"#)
            != FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"lt",5]]]"#))
    }

    @Test
    func changingALogicalOperatorIsNotEqual() {
        #expect(FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true]]]"#)
            != FilterRule(ruleType: .customFieldsQuery, value: #"["OR",[[7,"exists",true]]]"#))
    }

    @Test
    func addingAConditionIsNotEqual() {
        #expect(FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true]]]"#)
            != FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true],[8,"exists",true]]]"#))
    }

    // Reordering atoms is *not* equal either: the fragments carry their bracket runs, so `[[7`
    // and `[8` never line up with `[[8` and `[7`. The comma-splitting turns out not to lose
    // anything for this rule type, which is why `FilterRule` needs no change to support it.
    @Test
    func reorderingWholeAtomsIsNotEqual() {
        #expect(FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true],[8,"exists",true]]]"#)
            != FilterRule(ruleType: .customFieldsQuery, value: #"["AND",[[8,"exists",true],[7,"exists",true]]]"#))
    }
}
