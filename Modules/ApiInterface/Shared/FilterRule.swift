import Foundation

public struct FilterRule: Comparable, Codable, Equatable, Hashable, Sendable {
    public let ruleType: FilterRuleType
    public let value: String?

    public init(ruleType: FilterRuleType, value: String?) {
        self.ruleType = ruleType
        self.value = value
    }
}

public extension [FilterRule] {
    var merged: [FilterRule] {
        var merged = [FilterRule]()
        var previousRule: FilterRule?
        for var filterRule in self.sorted() {
            if let previousRule, filterRule.ruleType == previousRule.ruleType, filterRule.ruleType.shouldMergeValues {
                filterRule = FilterRule(
                    ruleType: filterRule.ruleType,
                    value: [previousRule.value, filterRule.value].compactMap { $0 }.sorted().joined(separator: ",")
                )
                merged[merged.count - 1] = filterRule
            } else {
                merged.append(filterRule)
            }
            previousRule = filterRule
        }
        return merged
    }

    var queryDictionary: [String: AnyHashable] {
        var queryValue: [String: AnyHashable] = [:]
        for filterRule in sorted() {
            if let value = queryValue[filterRule.ruleType.queryItemName] as? String {
                queryValue[filterRule.ruleType.queryItemName] = [value, filterRule.value].compactMap { $0 }.sorted()
                    .joined(separator: ",")
            } else {
                if filterRule.value == nil, let isNullQueryItemName = filterRule.ruleType.isNullQueryItemName {
                    queryValue[isNullQueryItemName] = true
                } else {
                    queryValue[filterRule.ruleType.queryItemName] = filterRule.value
                }
            }
        }
        return queryValue
    }
}

public extension FilterRule {
    static func == (lhs: FilterRule, rhs: FilterRule) -> Bool {
        lhs.ruleType == rhs.ruleType && lhs.value?.components(separatedBy: ",").sorted() == rhs.value?
            .components(separatedBy: ",").sorted()
    }

    static func < (lhs: FilterRule, rhs: FilterRule) -> Bool {
        if lhs.ruleType == rhs.ruleType {
            return lhs.value ?? "" < rhs.value ?? ""
        }
        return lhs.ruleType.rawValue < rhs.ruleType.rawValue
    }
}

public extension [FilterRule] {
    static func == (lhs: [FilterRule], rhs: [FilterRule]) -> Bool {
        if lhs.count != rhs.count {
            return false
        }

        for element in zip(lhs.sorted(), rhs.sorted()) where element.0 != element.1 {
            return false
        }
        return true
    }
}
