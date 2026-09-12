@testable import ApiImplementation

import ApiInterface
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite
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
    // depend on them - any string in the object will do.
    private static let syntheticFailureV10 = """
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
                "result_data": { "error": "not a valid pdf" },
                "related_document_ids": [],
                "acknowledged": false,
                "owner": 2
            }
        ]
    }
    """

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

    // v9 sends prose even on success; v10 sends none. Asserted rather than smoothed over, because a
    // future reader will otherwise "fix" the difference.
    @Test
    func v10_hasNoMessageForASuccess() throws {
        let task = try #require(try decodeV10(Self.recordedV10).results.first).asFileTask

        #expect(task.message == nil)
    }

    @Test
    func v10_readsAFailureMessageWithoutKnowingItsKey() throws {
        let task = try #require(try decodeV10(Self.syntheticFailureV10).results.first).asFileTask

        #expect(task.status == .failed)
        #expect(task.fileName == "broken.pdf")
        #expect(task.documentId == nil)
        #expect(task.message == "not a valid pdf")
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
