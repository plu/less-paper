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
}
