@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveStoragePathOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "id": 1,
          "is_insensitive": false,
          "match": "",
          "matching_algorithm": 6,
          "name": "Test StoragePath",
          "owner": 3,
          "path" : "\\/home\\/paperless\\/test-storagepath",
          "slug": "test-storagepath",
          "user_can_change": true
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveStoragePathOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
