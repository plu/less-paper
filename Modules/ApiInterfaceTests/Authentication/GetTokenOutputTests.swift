@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetTokenOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "token" : "s3cr3t-c0ff33"
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetTokenOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
