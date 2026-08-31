@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetSavedViewsOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "all": [
            1
          ],
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "display_fields" : null,
              "display_mode" : null,
              "filter_rules" : [],
              "id" : 1,
              "name" : "Test SavedView",
              "owner" : 3,
              "page_size" : null,
              "sort_field" : "added",
              "sort_reverse" : true,
              "user_can_change" : true
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetSavedViewsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue()]
        ))
    }

    // paperless-ngx stores sort_field as null=True/blank=True, so a saved view created without one
    // comes back as null. Captured verbatim from a 3.0.5 instance.
    @Test
    func decodeWithoutSortField() async throws {
        let json = """
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id" : 55,
              "name" : "Kein Sortierfeld",
              "sort_field" : null,
              "sort_reverse" : false,
              "filter_rules" : [],
              "page_size" : null,
              "display_mode" : null,
              "display_fields" : null,
              "owner" : 2,
              "user_can_change" : true
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetSavedViewsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue(
                id: 55,
                name: "Kein Sortierfeld",
                owner: 2,
                sortDirection: .ascending,
                sortField: .created
            )]
        ))
    }

    // Rule types 48 and 49 are the newest paperless-ngx defines; anything above them belongs to a
    // paperless newer than this app, and must not cost the user the whole decode.
    @Test
    func decodeDropsUnknownFilterRuleTypes() async throws {
        let json = """
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id" : 1,
              "name" : "Test SavedView",
              "sort_field" : "added",
              "sort_reverse" : true,
              "filter_rules" : [
                { "rule_type" : 48, "value" : "Rechnung" },
                { "rule_type" : 999, "value" : "from a newer paperless" },
                { "rule_type" : 49, "value" : "Steuer" }
              ],
              "owner" : 3,
              "user_can_change" : true
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetSavedViewsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue(filterRules: [
                FilterRule(ruleType: .simpleTitle, value: "Rechnung"),
                FilterRule(ruleType: .simpleText, value: "Steuer")
            ])]
        ))
    }
}
