@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct CustomFieldTests {

    @Test
    func decode_select() async throws {
        let json = """
        {
          "id": 1,
          "name": "Status",
          "data_type": "select",
          "extra_data": {
            "select_options": [
              { "label": "Open", "id": "aqgT3m4XZw8aw3Ou" },
              { "label": "Closed", "id": "MOddUdj2nhfCEsqp" }
            ]
          },
          "document_count": 4
        }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(customField, .testValue(
            dataType: .select,
            documentCount: 4,
            extraData: .init(selectOptions: [
                .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
                .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
            ]),
            name: "Status"
        ))
    }

    // The POST response omits document_count entirely — it is present on list and PATCH only.
    @Test
    func decode_withoutDocumentCount() async throws {
        let json = """
        { "id": 3, "name": "Reference", "data_type": "string", "extra_data": null }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        #expect(customField.documentCount == 0)
        #expect(customField.extraData == nil)
    }

    // A data type added by a future paperless release must not fail the whole list.
    @Test
    func decode_unknownDataType() async throws {
        let json = """
        { "id": 4, "name": "Future", "data_type": "somethingnew", "document_count": 0 }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        #expect(customField.dataType == .unknown)
    }

    @Test
    func allCases_excludesUnknown() async throws {
        #expect(!CustomFieldDataType.allCases.contains(.unknown))
        #expect(CustomFieldDataType.allCases.count == 10)
    }

    // Eleven hand-written mappings: a case wired to the wrong string still compiles.
    @Test
    func description_mapsEveryDataTypeToItsOwnString() async throws {
        let descriptions = CustomFieldDataType.allCases.map(\.description)

        #expect(descriptions == [
            "Text",
            "URL",
            "Date",
            "Boolean",
            "Integer",
            "Number",
            "Monetary",
            "Document link",
            "Select",
            "Long text"
        ])
        #expect(CustomFieldDataType.unknown.description == "Unknown")
    }

    @Test
    func comparable_sortsByName() async throws {
        let sorted = [CustomField.testValue(id: 2, name: "Beta"), .testValue(id: 1, name: "Alpha")].sorted()

        #expect(sorted.map(\.name) == ["Alpha", "Beta"])
    }
}
