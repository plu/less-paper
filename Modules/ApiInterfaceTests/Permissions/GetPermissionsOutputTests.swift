@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetPermissionsOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "owner": 42,
          "permissions": {
            "change": {
              "groups": [1, 2, 3],
              "users": [4, 5, 6]
            },
            "view": {
              "groups": [7, 8, 9],
              "users": [10, 11, 12]
            }
          }
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetPermissionsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
