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

    // paperless stores extra_data as an unvalidated JSON blob - its select_options check only runs
    // when the field is, or is becoming, a select - so an option can arrive as null. Captured
    // verbatim from a 3.0.5 instance.
    @Test
    func decodeDropsNullSelectOptions() async throws {
        let json = """
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id": 208,
              "name": "claude-repro-select-null",
              "data_type": "select",
              "extra_data": {
                "select_options": [
                  null,
                  {
                    "label": "Open",
                    "id": "J5ZwxH9QAyYT83Jj"
                  }
                ]
              },
              "document_count": 0
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetCustomFieldsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue(
                dataType: .select,
                extraData: .testValue(selectOptions: [.testValue(id: "J5ZwxH9QAyYT83Jj")]),
                id: 208,
                name: "claude-repro-select-null"
            )]
        ))
    }

    // paperless's own web UI pushes { label: null, id: null } for an option the user has added but
    // not yet typed into, and nothing rejects it on a field that is not a select. Captured verbatim
    // from a 3.0.5 instance.
    @Test
    func decodeDropsSelectOptionsWithoutALabel() async throws {
        let json = """
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id": 212,
              "name": "claude-labelless",
              "data_type": "string",
              "extra_data": {
                "select_options": [
                  {
                    "label": null,
                    "id": null
                  }
                ]
              },
              "document_count": 0
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetCustomFieldsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue(
                extraData: .testValue(selectOptions: []),
                id: 212,
                name: "claude-labelless"
            )]
        ))
    }
}
