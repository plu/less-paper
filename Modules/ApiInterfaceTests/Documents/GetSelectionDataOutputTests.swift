@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetSelectionDataOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "selected_correspondents": [
            {
              "document_count": 2,
              "id": 1
            }
          ],
          "selected_document_types": [
            {
              "document_count": 1,
              "id": 2
            }
          ],
          "selected_storage_paths": [
            {
              "document_count": 3,
              "id": 3
            }
          ],
          "selected_tags": [
            {
              "document_count": 4,
              "id": 4
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetSelectionDataOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
