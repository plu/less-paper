@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct AuditLogEntryTests {

    @Test
    func decoding_readsAnM2MChangeAndItsActor() throws {
        let entry = try decode(#"""
        {"id": 106, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "update",
         "changes": {"tags": {"type": "m2m", "operation": "add", "objects": ["Audio", "Manual"]}},
         "actor": {"id": 2, "username": "admin"}}
        """#)

        #expect(entry.id == 106)
        #expect(entry.action == .update)
        #expect(entry.actor == .testValue(id: 2, username: "admin"))
        #expect(entry.changes == [.relation(key: "tags", operation: "add", objects: ["Audio", "Manual"])])
    }

    @Test
    func decoding_readsFieldChangesSortedByKeyWithNoneAsNil() throws {
        let entry = try decode(#"""
        {"id": 105, "timestamp": "2026-09-07T11:37:29.576535Z", "action": "update",
         "changes": {"storage_path": ["None", "3"], "correspondent": ["None", "8"]},
         "actor": null}
        """#)

        #expect(entry.actor == nil)
        #expect(entry.changes == [
            .field(key: "correspondent", old: nil, new: .string("8")),
            .field(key: "storage_path", old: nil, new: .string("3")),
        ])
    }

    // Not every pair is two strings: notes send a number, and a tag change written outside the bulk
    // editor sends raw ids — the source of the web's "Tags: 7".
    @Test
    func decoding_keepsNonStringPairs() throws {
        let entry = try decode(#"""
        {"id": 3234, "timestamp": "2026-09-25T17:51:35.821786Z", "action": "update",
         "changes": {"Note Added": ["None", 40], "tags": [null, [102]]}, "actor": null}
        """#)

        #expect(entry.changes == [
            .field(key: "Note Added", old: nil, new: .number(40)),
            .field(key: "tags", old: nil, new: .array([.number(102)])),
        ])
    }

    @Test
    func decoding_readsACustomFieldChange() throws {
        let entry = try decode(#"""
        {"id": 7, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "create",
         "changes": {"custom_fields": {"type": "custom_field", "field": "Invoice", "value": "42"}},
         "actor": {"id": 2, "username": "admin"}}
        """#)

        #expect(entry.action == .create)
        #expect(entry.changes == [.customField(field: "Invoice", value: "42")])
    }

    @Test
    func decoding_skipsAnUnknownChangeShapeAndKeepsTheRest() throws {
        let entry = try decode(#"""
        {"id": 8, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "update",
         "changes": {"mystery": {"type": "something_new"}, "title": ["Old", "New"]}, "actor": null}
        """#)

        #expect(entry.changes == [.field(key: "title", old: .string("Old"), new: .string("New"))])
    }

    @Test
    func decoding_keepsAnUnknownActionAsOther() throws {
        let entry = try decode(#"""
        {"id": 9, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "access", "changes": {}, "actor": null}
        """#)

        #expect(entry.action == .other("access"))
        #expect(entry.changes.isEmpty)
    }

    @Test
    func decoding_readsAListResponse() throws {
        let entries = try JSONDecoder.apiDecoder.decode(
            [AuditLogEntry].self,
            from: Data(#"""
            [{"id": 2, "timestamp": "2026-09-07T11:30:00.620678Z", "action": "update",
              "changes": {"created": ["2026-09-07", "2026-09-07 13:29:34+02:00"]}, "actor": null},
             {"id": 1, "timestamp": "2026-09-07T11:30:00.613971Z", "action": "create",
              "changes": {"title": ["None", "Sonos Sub"]}, "actor": null}]
            """#.utf8)
        )

        #expect(entries.map(\.id) == [2, 1])
    }

    private func decode(_ json: String) throws -> AuditLogEntry {
        try JSONDecoder.apiDecoder.decode(AuditLogEntry.self, from: Data(json.utf8))
    }
}
