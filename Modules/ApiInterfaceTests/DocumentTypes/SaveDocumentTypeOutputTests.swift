@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct SaveDocumentTypeOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "id": 1,
          "is_insensitive": false,
          "match": "",
          "matching_algorithm": 6,
          "name": "Test DocumentType",
          "owner": 3,
          "slug": "test-document-type",
          "user_can_change": true
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveDocumentTypeOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
