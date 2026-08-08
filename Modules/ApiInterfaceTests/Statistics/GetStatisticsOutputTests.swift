@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite(
    .dependencies()
)
struct GetStatisticsOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "documents_total": 15,
          "documents_inbox": 1,
          "inbox_tag": 104,
          "inbox_tags": [
            104,
            105,
            106
          ],
          "document_file_type_counts": [
            {
              "mime_type": "application/pdf",
              "mime_type_count": 15
            }
          ],
          "character_count": 11455,
          "tag_count": 4,
          "correspondent_count": 0,
          "document_type_count": 0,
          "storage_path_count": 0,
          "current_asn": 2
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetStatisticsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }

    @Test
    func decodeWithNullInboxTag() async throws {
        let json = """
        {
          "documents_total": 20,
          "documents_inbox": 0,
          "inbox_tag": null,
          "inbox_tags": [],
          "document_file_type_counts": [
            {
              "mime_type": "application/pdf",
              "mime_type_count": 18
            },
            {
              "mime_type": "image/png",
              "mime_type_count": 2
            }
          ],
          "character_count": 25000,
          "tag_count": 10,
          "correspondent_count": 5,
          "document_type_count": 3,
          "storage_path_count": 2,
          "current_asn": 10
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetStatisticsOutput.self, from: #require(json.data(using: .utf8)))

        let expected = GetStatisticsOutput(
            characterCount: 25000,
            correspondentCount: 5,
            currentAsn: 10,
            documentFileTypeCounts: [
                .init(mimeType: "application/pdf", mimeTypeCount: 18),
                .init(mimeType: "image/png", mimeTypeCount: 2)
            ],
            documentTypeCount: 3,
            documentsInbox: 0,
            documentsTotal: 20,
            inboxTag: nil,
            inboxTags: [],
            storagePathCount: 2,
            tagCount: 10
        )

        expectNoDifference(output, expected)
    }

    @Test
    func decodeWithMultipleFileTypes() async throws {
        let json = """
        {
          "documents_total": 100,
          "documents_inbox": 5,
          "inbox_tag": 1,
          "inbox_tags": [1],
          "document_file_type_counts": [
            {
              "mime_type": "application/pdf",
              "mime_type_count": 75
            },
            {
              "mime_type": "image/jpeg",
              "mime_type_count": 15
            },
            {
              "mime_type": "image/png",
              "mime_type_count": 8
            },
            {
              "mime_type": "text/plain",
              "mime_type_count": 2
            }
          ],
          "character_count": 150000,
          "tag_count": 25,
          "correspondent_count": 12,
          "document_type_count": 8,
          "storage_path_count": 4,
          "current_asn": 50
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetStatisticsOutput.self, from: #require(json.data(using: .utf8)))

        let expected = GetStatisticsOutput(
            characterCount: 150000,
            correspondentCount: 12,
            currentAsn: 50,
            documentFileTypeCounts: [
                .init(mimeType: "application/pdf", mimeTypeCount: 75),
                .init(mimeType: "image/jpeg", mimeTypeCount: 15),
                .init(mimeType: "image/png", mimeTypeCount: 8),
                .init(mimeType: "text/plain", mimeTypeCount: 2)
            ],
            documentTypeCount: 8,
            documentsInbox: 5,
            documentsTotal: 100,
            inboxTag: 1,
            inboxTags: [1],
            storagePathCount: 4,
            tagCount: 25
        )

        expectNoDifference(output, expected)
    }

    @Test
    func decodeWithNullCounts() async throws {
        let json = """
        {
          "documents_total": 13,
          "documents_inbox": null,
          "inbox_tag": null,
          "inbox_tags": null,
          "document_file_type_counts": [
            {
              "mime_type": "application/pdf",
              "mime_type_count": 13
            }
          ],
          "character_count": 9134,
          "tag_count": null,
          "correspondent_count": null,
          "document_type_count": null,
          "storage_path_count": null,
          "current_asn": null
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetStatisticsOutput.self, from: #require(json.data(using: .utf8)))

        let expected = GetStatisticsOutput(
            characterCount: 9134,
            correspondentCount: 0,
            currentAsn: 0,
            documentFileTypeCounts: [
                .init(mimeType: "application/pdf", mimeTypeCount: 13)
            ],
            documentTypeCount: 0,
            documentsInbox: 0,
            documentsTotal: 13,
            inboxTag: nil,
            inboxTags: [],
            storagePathCount: 0,
            tagCount: 0
        )

        expectNoDifference(output, expected)
    }
}
