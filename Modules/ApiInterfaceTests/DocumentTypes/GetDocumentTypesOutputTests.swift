@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetDocumentTypesOutputTests {

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
              "document_count": 0,
              "id": 1,
              "is_insensitive": false,
              "match": "",
              "matching_algorithm": 6,
              "name": "Test DocumentType",
              "owner": 3,
              "slug": "test-document-type",
              "user_can_change": true
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetDocumentTypesOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue()]
        ))
    }
}
