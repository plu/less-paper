@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveCorrespondentOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "id": 1,
          "is_insensitive": false,
          "match": "",
          "matching_algorithm": 6,
          "name": "Test Correspondent",
          "owner": 3,
          "slug": "test-correspondent",
          "user_can_change": true
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveCorrespondentOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
