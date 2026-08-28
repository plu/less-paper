@testable import ApiImplementation

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(.dependencies())
struct TrashPayloadTests {

    /// A real response from `GET /api/trash/`, recorded from a paperless 3.0.5 instance.
    ///
    /// The point is that a trashed document decodes as an ordinary `Document`. It carries fields the
    /// documents endpoint never sends - `deleted_at`, `root_document`, `versions` - and the whole
    /// feature rests on the list being usable as documents, because `/api/documents/{id}/` answers
    /// 404 once something is in here.
    private static let recorded = """
    {
    "count": 45,
    "next": "http://192.168.64.1:8000/api/trash/?page=2",
    "previous": null,
    "results": [
        {
            "id": 70,
            "correspondent": null,
            "document_type": null,
            "storage_path": null,
            "title": "Bulk Edit Set Storage Path Test DC944005-23C2-42CB-878C-9F55AFCDFC79",
            "content": "Test PDF content",
            "tags": [],
            "created": "2026-08-28",
            "created_date": "2026-08-28",
            "modified": "2026-08-28T10:06:34.658941+02:00",
            "added": "2026-08-28T10:06:33.218447+02:00",
            "deleted_at": "2026-08-28T10:06:35.212660+02:00",
            "archive_serial_number": null,
            "original_file_name": "test.pdf",
            "archived_file_name": null,
            "duplicate_documents": [],
            "owner": 2,
            "user_can_change": true,
            "is_shared_by_requester": false,
            "notes": [],
            "custom_fields": [],
            "page_count": null,
            "mime_type": "text/plain",
            "root_document": null,
            "versions": [
                {
                    "id": 70,
                    "added": "2026-08-28T08:06:33.218447Z",
                    "version_label": null,
                    "checksum": "12cde1fe03616c66631b1047ff48f8d051b2c97da614face73f2cc4525dda4fb",
                    "is_root": true
                }
            ]
        }
    ]
    }
    """

    @Test
    func test_trashResponse_decodesAsDocuments() throws {
        let output = try JSONDecoder.apiDecoder.decode(
            GetTrashOutput.self,
            from: Data(Self.recorded.utf8)
        )

        #expect(output.count == 45)
        #expect(output.next != nil)

        let document = try #require(output.results.first)
        #expect(document.id.rawValue == 70)
        #expect(!document.title.isEmpty)
    }
}
