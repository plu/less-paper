@testable import ApiImplementation

import ApiInterface
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(.dependencies())
struct FileTaskPayloadTests {

    // GET /api/tasks/?task_type=consume_file with `Accept: application/json; version=9`, recorded
    // from a paperless 3.0.5 instance. No envelope: v9 answers with a bare array and ignores
    // page_size entirely.
    private static let recordedV9 = """
    [
        {
            "id": 267,
            "task_id": "04c46ed1-fe50-45f6-a623-f14ce8dd9a4c",
            "task_name": "consume_file",
            "task_file_name": "test.pdf",
            "type": "manual_task",
            "status": "SUCCESS",
            "date_created": "2026-09-08T14:48:16.989002+02:00",
            "date_done": "2026-09-08T14:48:17.130038+02:00",
            "result": "Success. New document id 43 created",
            "acknowledged": false,
            "related_document": 43,
            "duplicate_documents": [],
            "owner": 2
        },
        {
            "id": 1001,
            "task_id": "80d96522-269a-43c7-a230-0060d9b8e82f",
            "task_name": "check_workflows",
            "task_file_name": null,
            "type": "scheduled_task",
            "status": "SUCCESS",
            "date_created": "2026-09-12T09:05:00.014703+02:00",
            "date_done": "2026-09-12T09:05:00.326820+02:00",
            "result": null,
            "acknowledged": false,
            "related_document": null,
            "duplicate_documents": [],
            "owner": null
        }
    ]
    """

    // GET /api/tasks/ recorded directly from a real paperless 2.15.3 instance (`x-api-version: 8`).
    // Real 2.x servers send related_document as a JSON *string* ("1"), unlike recordedV9 above,
    // which was recorded from a 3.0.5 instance impersonating v9 and sends an integer. Confirmed
    // against both 2.15.3 and 2.19.6.
    private static let recordedV9RealServer = """
    [
        {
            "id": 2,
            "task_id": "d98797e0-b11b-4b75-8019-365292067ec5",
            "task_name": "consume_file",
            "task_file_name": "Sonos One.pdf",
            "date_created": "2026-09-12T20:08:19.248632+02:00",
            "date_done": "2026-09-12T20:08:19.282073+02:00",
            "type": "auto_task",
            "status": "FAILURE",
            "result": "Sonos One.pdf: Not consuming Sonos One.pdf: It is a duplicate of probe-2.15.3 (#1).",
            "acknowledged": false,
            "related_document": "1",
            "owner": 3
        },
        {
            "id": 1,
            "task_id": "6767e468-9a6b-4ace-a4a2-075f49bc0b10",
            "task_name": "consume_file",
            "task_file_name": "Sonos One.pdf",
            "date_created": "2026-09-12T20:07:19.220689+02:00",
            "date_done": "2026-09-12T20:07:20.431745+02:00",
            "type": "auto_task",
            "status": "SUCCESS",
            "result": "Success. New document id 1 created",
            "acknowledged": false,
            "related_document": "1",
            "owner": 3
        }
    ]
    """

    // The same task 267, requested at version 10. Different envelope, different field names, and a
    // result that is an object rather than prose.
    private static let recordedV10 = """
    {
        "count": 43,
        "next": "http://192.168.64.1:8000/api/tasks/?ordering=-date_created&page=2&page_size=2&task_type=consume_file",
        "previous": null,
        "results": [
            {
                "id": 267,
                "task_id": "04c46ed1-fe50-45f6-a623-f14ce8dd9a4c",
                "task_type": "consume_file",
                "task_type_display": "Consume File",
                "trigger_source": "api_upload",
                "trigger_source_display": "API Upload",
                "status": "success",
                "status_display": "Success",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "date_started": "2026-09-08T14:48:16.992843+02:00",
                "date_done": "2026-09-08T14:48:17.130038+02:00",
                "duration_seconds": 0.137195,
                "wait_time_seconds": 0.003841,
                "input_data": {
                    "filename": "test.pdf",
                    "mime_type": "text/plain",
                    "overrides": {
                        "filename": "test.pdf",
                        "title": "Bulk Edit Set Storage Path Test F5E951B9-7ABA-4484-AF18-CB71E3F48EFE",
                        "created": "2026-09-08",
                        "owner_id": 2,
                        "skip_asn_if_exists": false
                    }
                },
                "result_data": {
                    "document_id": 43
                },
                "related_document_ids": [
                    43
                ],
                "acknowledged": false,
                "owner": 2
            }
        ]
    }
    """

    // The failure shape is the one thing that could not be recorded: the dev instance has no failed
    // consume task. result_data's failure keys are therefore a guess, and the mapping must not
    // depend on them - any string in the object will do, and a payload with no string at all still
    // has to say something.
    private static let syntheticFailureV10 = syntheticFailure(
        resultData: #"{"error": "not a valid pdf"}"#
    )

    private static func syntheticFailure(resultData: String) -> String {
        """
        {
            "count": 1,
            "next": null,
            "previous": null,
            "results": [
                {
                    "id": 300,
                    "task_id": "11111111-2222-3333-4444-555555555555",
                    "task_type": "consume_file",
                    "task_type_display": "Consume File",
                    "trigger_source": "api_upload",
                    "trigger_source_display": "API Upload",
                    "status": "failure",
                    "status_display": "Failure",
                    "date_created": "2026-09-08T14:48:16.989002+02:00",
                    "date_started": "2026-09-08T14:48:16.992843+02:00",
                    "date_done": "2026-09-08T14:48:17.130038+02:00",
                    "duration_seconds": 0.1,
                    "wait_time_seconds": 0.1,
                    "input_data": { "filename": "broken.pdf" },
                    "result_data": \(resultData),
                    "related_document_ids": [],
                    "acknowledged": false,
                    "owner": 2
                }
            ]
        }
        """
    }

    private func decodeV9() throws -> [FileTaskPayloadV9] {
        try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(Self.recordedV9.data(using: .utf8))
        )
    }

    private func decodeV10(_ json: String) throws -> FileTaskListOutputV10 {
        try JSONDecoder.apiDecoder.decode(
            FileTaskListOutputV10.self,
            from: #require(json.data(using: .utf8))
        )
    }

    // The whole point of two payload structs: the same task, read off two different wires, is the
    // same row to everything above this layer.
    @Test
    func bothVersions_agreeOnEverythingTheScreenShows() throws {
        let v9 = try #require(decodeV9().first).asFileTask
        let v10 = try #require(try decodeV10(Self.recordedV10).results.first).asFileTask

        #expect(v9.id == v10.id)
        #expect(v9.fileName == v10.fileName)
        #expect(v9.status == v10.status)
        #expect(v9.dateCreated == v10.dateCreated)
        #expect(v9.dateDone == v10.dateDone)
        #expect(v9.documentId == v10.documentId)
        #expect(v9.isAcknowledged == v10.isAcknowledged)
    }

    @Test
    func v9_mapsTheRecordedConsumeTask() throws {
        let task = try #require(decodeV9().first).asFileTask

        #expect(task.id == 267)
        #expect(task.fileName == "test.pdf")
        #expect(task.status == .complete)
        #expect(task.documentId == 43)
        #expect(task.isAcknowledged == false)
        #expect(task.message == "Success. New document id 43 created")
    }

    // A real 2.x server sends related_document as a JSON string, not the integer a 3.0.5 instance
    // impersonating v9 sends (see v9_mapsTheRecordedConsumeTask). Decoding "1" into an Int-backed
    // Tagged used to throw typeMismatch and fail the whole page.
    @Test
    func v9_decodesAStringRelatedDocumentFromARealServer() throws {
        let payloads = try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(Self.recordedV9RealServer.data(using: .utf8))
        )

        let failed = try #require(payloads.first).asFileTask
        #expect(failed.id == 2)
        #expect(failed.documentId == 1)
        #expect(failed.status == .failed)
        #expect(failed.fileName == "Sonos One.pdf")

        let succeeded = try #require(payloads.last).asFileTask
        #expect(succeeded.id == 1)
        #expect(succeeded.documentId == 1)
        #expect(succeeded.status == .complete)
        #expect(succeeded.message == "Success. New document id 1 created")
    }

    // The fallback's third branch: no known server sends this, but decodeRelatedDocument's own
    // contract is that a related_document which is neither Document.Id nor a numeric string - and
    // one that is missing entirely - must not throw. Either failure mode would take the whole row,
    // and with it the whole page, down with it.
    @Test
    func v9_relatedDocumentDecodesAsNilRatherThanThrowing_whenNonNumericOrAbsent() throws {
        let json = """
        [
            {
                "id": 5,
                "task_name": "consume_file",
                "task_file_name": "a.pdf",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "status": "SUCCESS",
                "acknowledged": false,
                "related_document": "abc"
            },
            {
                "id": 6,
                "task_name": "consume_file",
                "task_file_name": "b.pdf",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "status": "SUCCESS",
                "acknowledged": false
            }
        ]
        """
        let payloads = try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(json.data(using: .utf8))
        )

        let nonNumeric = try #require(payloads.first).asFileTask
        #expect(nonNumeric.id == 5)
        #expect(nonNumeric.fileName == "a.pdf")
        #expect(nonNumeric.documentId == nil)

        let absent = try #require(payloads.last).asFileTask
        #expect(absent.id == 6)
        #expect(absent.fileName == "b.pdf")
        #expect(absent.documentId == nil)
    }

    // Old servers have no task_type filter to honour, so the client has to recognise its own rows.
    @Test
    func v9_marksOnlyConsumeFileTasks() throws {
        let payloads = try decodeV9()

        #expect(payloads.map(\.isConsumeFile) == [true, false])
    }

    @Test
    func v10_mapsTheRecordedConsumeTask() throws {
        let output = try decodeV10(Self.recordedV10)
        let task = try #require(output.results.first).asFileTask

        #expect(task.id == 267)
        #expect(task.fileName == "test.pdf")
        #expect(task.status == .complete)
        #expect(task.documentId == 43)
        #expect(task.isAcknowledged == false)
        #expect(output.count == 43)
    }

    // v9 sends prose even on success; v10 sends none, only `{"document_id": 43}`. Asserted rather
    // than smoothed over, because a future reader will otherwise "fix" the difference. The mapping
    // stays dumb and hands over the raw object; the view shows a message on failed rows only, so
    // nothing displays this.
    @Test
    func v10_hasNoProseForASuccess() throws {
        let v9 = try #require(decodeV9().first).asFileTask
        let v10 = try #require(try decodeV10(Self.recordedV10).results.first).asFileTask

        #expect(v9.message == "Success. New document id 43 created")
        // Snake case, and deliberately asserted that way: the keys inside a decoded
        // [String: JSONValue] are not rewritten by convertFromSnakeCase, whatever the mapping's own
        // comment above documentId says. Reading both spellings is what makes that harmless.
        #expect(v10.message == #"{"document_id":43}"#)
    }

    @Test
    func v10_readsAFailureMessageWithoutKnowingItsKey() throws {
        let task = try #require(try decodeV10(Self.syntheticFailureV10).results.first).asFileTask

        #expect(task.status == .failed)
        #expect(task.fileName == "broken.pdf")
        #expect(task.documentId == nil)
        #expect(task.message == "not a valid pdf")
    }

    // The insurance tier. A failure whose values are all arrays or objects would otherwise render a
    // failed row with nothing beside it, on the one screen whose entire job is saying what happened.
    @Test
    func v10_fallsBackToTheRawJsonWhenNoValueIsAString() throws {
        let task = try #require(
            try decodeV10(Self.syntheticFailure(resultData: #"{"errors": ["duplicate"]}"#))
                .results
                .first
        ).asFileTask

        #expect(task.message == #"{"errors":["duplicate"]}"#)
    }

    // And an absent result_data is the one case that legitimately has nothing to say.
    @Test
    func v10_hasNoMessageWithoutResultData() throws {
        let task = try #require(
            try decodeV10(Self.syntheticFailure(resultData: "null")).results.first
        ).asFileTask

        #expect(task.message == nil)
    }

    // A page must survive a row that is missing related_document_ids: one absent key taking every
    // other row on the page with it is the failure mode every decision here is shaped against.
    @Test
    func v10_decodesARowWithoutRelatedDocumentIds() throws {
        let json = """
        {
            "count": 1,
            "next": null,
            "previous": null,
            "results": [
                {
                    "id": 301,
                    "task_type": "consume_file",
                    "status": "success",
                    "date_created": "2026-09-08T14:48:16.989002+02:00",
                    "date_done": null,
                    "input_data": { "filename": "a.pdf" },
                    "result_data": null,
                    "acknowledged": false
                }
            ]
        }
        """
        let task = try #require(try decodeV10(json).results.first).asFileTask

        #expect(task.id == 301)
        #expect(task.documentId == nil)
    }

    @Test
    func unknownStatus_readsAsQueued() throws {
        let json = """
        [
            {
                "id": 1,
                "task_id": "x",
                "task_name": "consume_file",
                "task_file_name": "a.pdf",
                "type": "manual_task",
                "status": "SOMETHING_NEW",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "date_done": null,
                "result": null,
                "acknowledged": false,
                "related_document": null,
                "duplicate_documents": [],
                "owner": 2
            }
        ]
        """
        let payloads = try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(json.data(using: .utf8))
        )

        #expect(try #require(payloads.first).asFileTask.status == .queued)
    }
}
