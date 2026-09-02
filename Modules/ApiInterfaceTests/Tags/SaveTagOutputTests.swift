@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveTagOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "color": "#F7CE46",
          "id": 1,
          "is_inbox_tag": true,
          "is_insensitive": false,
          "match": "",
          "matching_algorithm": 6,
          "name": "Inbox",
          "owner": 3,
          "slug": "inbox",
          "text_color": "#000000",
          "user_can_change": true
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveTagOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
