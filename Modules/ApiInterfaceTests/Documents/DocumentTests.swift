@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentTests {

    // API 8 sends `created` as a datetime at the server's local midnight. Decoding that instant and
    // rendering it in the device's time zone lands on 5 December for anyone west of the server, so
    // the calendar date the server meant has to win.
    @Test
    func decoding_takesTheCalendarDateFromAnApi8Payload() throws {
        let document = try JSONDecoder.apiDecoder.decode(
            Document.self,
            from: Data(payload(created: "2023-12-06T00:00:00+01:00", createdDate: "2023-12-06").utf8)
        )

        #expect(document.created == Date(timeIntervalSince1970: 1_701_820_800))
    }

    @Test
    func decoding_takesTheCalendarDateFromAnApi9Payload() throws {
        let document = try JSONDecoder.apiDecoder.decode(
            Document.self,
            from: Data(payload(created: "2023-12-06", createdDate: "2023-12-06").utf8)
        )

        #expect(document.created == Date(timeIntervalSince1970: 1_701_820_800))
    }

    // `created_date` is deprecated upstream and slated for removal. `created` is already a plain
    // date from API 9 on, so it is a safe fallback once the field goes away.
    @Test
    func decoding_fallsBackToCreatedWhenTheDeprecatedFieldIsGone() throws {
        let document = try JSONDecoder.apiDecoder.decode(
            Document.self,
            from: Data(payload(created: "2023-12-06", createdDate: nil).utf8)
        )

        #expect(document.created == Date(timeIntervalSince1970: 1_701_820_800))
    }
}

private extension DocumentTests {

    func payload(created: String, createdDate: String?) -> String {
        let createdDateEntry = createdDate.map { "\"created_date\": \"\($0)\"," } ?? ""
        return """
        {
            "added": "2023-12-07T09:30:00+01:00",
            "archive_serial_number": 42,
            "archived_file_name": "invoice.pdf",
            "content": "Some invoice",
            "correspondent": 1,
            "created": "\(created)",
            \(createdDateEntry)
            "document_type": 1,
            "id": 1,
            "modified": "2023-12-07T09:30:00+01:00",
            "original_file_name": "invoice.pdf",
            "owner": 1,
            "storage_path": 1,
            "tags": [1],
            "title": "Invoice"
        }
        """
    }
}
