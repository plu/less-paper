@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite(
    .testDependencies()
)
struct GlobalSearchOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "total": 2,
          "documents": [
            {
              "id": 8,
              "correspondent": 7,
              "document_type": 4,
              "storage_path": 3,
              "title": "Puky",
              "content": "KINDERFAHRRAD",
              "tags": [5],
              "created": "2022-04-23",
              "created_date": "2022-04-23",
              "modified": "2026-09-20T11:46:21.299051+02:00",
              "added": "2026-09-20T11:40:21.433921+02:00",
              "archive_serial_number": 5,
              "original_file_name": "Puky.pdf",
              "owner": null,
              "user_can_change": true,
              "notes": [],
              "custom_fields": []
            }
          ],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "custom_fields": [],
          "tags": [
            {
              "id": 7,
              "slug": "manual",
              "name": "Manual",
              "color": "#1f78b4",
              "text_color": "#ffffff",
              "match": "",
              "matching_algorithm": 1,
              "is_insensitive": true,
              "is_inbox_tag": false,
              "owner": null,
              "user_can_change": true,
              "parent": null,
              "children": []
            }
          ],
          "users": [],
          "groups": [],
          "mail_rules": [],
          "mail_accounts": [],
          "workflows": []
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(output.documents.map(\.title) == ["Puky"])
        #expect(output.tags.map(\.name) == ["Manual"])
        #expect(output.isEmpty == false)
    }

    // The five types this app has no screen for are not decoded at all, so a payload full of them
    // must reach consumers as nothing.
    @Test
    func decode_ignoresUnsupportedTypes() async throws {
        let json = """
        {
          "total": 5,
          "documents": [],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "custom_fields": [],
          "tags": [],
          "users": [{"id": 3, "username": "admin"}],
          "groups": [{"id": 1, "name": "editors"}],
          "mail_rules": [{"id": 1, "name": "rule"}],
          "mail_accounts": [{"id": 1, "name": "account"}],
          "workflows": [{"id": 1, "name": "flow"}]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        expectNoDifference(output, .testValue())
        #expect(output.isEmpty)
    }

    // `custom_fields` postdates the search endpoint, so a server that omits the key must decode
    // rather than fail the whole response and break search entirely.
    @Test
    func decode_toleratesMissingCustomFields() async throws {
        let json = """
        {
          "total": 0,
          "documents": [],
          "saved_views": [],
          "correspondents": [],
          "document_types": [],
          "storage_paths": [],
          "tags": []
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(
            GlobalSearchOutput.self,
            from: #require(json.data(using: .utf8))
        )

        expectNoDifference(output, .testValue())
    }
}
