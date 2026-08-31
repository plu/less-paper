@testable import ApiInterface

import Foundation
import Testing

@Suite
struct FilterRuleTypeTests {

    // paperless-ngx numbers its rule types 0...49 with no gaps. A saved view carrying one this app
    // does not know decodes to nothing and the rule is silently dropped, so the gap is worth a test
    // rather than a discovery.
    @Test
    func coversEveryRuleTypePaperlessDefines() async throws {
        let known = Set(FilterRuleType.allCases.map(\.rawValue))

        #expect(Set(0 ... 49).isSubset(of: known))
    }

    @Test(arguments: [
        (FilterRuleType.simpleTitle, "title_search"),
        (FilterRuleType.simpleText, "text"),
        (FilterRuleType.mimeType, "mime_type")
    ])
    func queryItemName(ruleType: FilterRuleType, expected: String) async throws {
        #expect(ruleType.queryItemName == expected)
    }
}
