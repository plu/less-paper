import ApiInterface
import Foundation

// GET /api/tasks/ as answered by API version 9 and below: a bare array, no pagination, no filtering
// to rely on. `type` here is the trigger (manual_task, auto_task, scheduled_task) and `task_name` is
// the task - v10 swaps those names round, which is the trap this struct exists to absorb.
struct FileTaskPayloadV9: Decodable {

    let acknowledged: Bool

    let dateCreated: Date

    let dateDone: Date?

    let id: FileTask.Id

    let relatedDocument: Document.Id?

    let result: String?

    let status: String

    let taskFileName: String?

    let taskName: String?
}

extension FileTaskPayloadV9 {

    var isConsumeFile: Bool {
        taskName == "consume_file"
    }

    var asFileTask: FileTask {
        FileTask(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: relatedDocument,
            fileName: taskFileName,
            id: id,
            isAcknowledged: acknowledged,
            message: result,
            status: FileTaskStatus(apiValue: status) ?? .queued
        )
    }
}
