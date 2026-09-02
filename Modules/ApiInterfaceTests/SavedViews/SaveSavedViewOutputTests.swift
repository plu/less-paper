@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveSavedViewOutputTests {

    @Test
    func decode() async throws {
        let json = """
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
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveSavedViewOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
