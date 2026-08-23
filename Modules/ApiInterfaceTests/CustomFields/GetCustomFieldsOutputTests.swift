@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetCustomFieldsOutputTests {

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
              "data_type": "string",
              "document_count": 0,
              "extra_data": null,
              "id": 1,
              "name": "Test CustomField"
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetCustomFieldsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue()]
        ))
    }
}
