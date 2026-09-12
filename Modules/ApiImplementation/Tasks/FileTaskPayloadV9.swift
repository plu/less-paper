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

    // A real 2.x server sends this as a JSON string ("1"), confirmed by probing both 2.15.3 and
    // 2.19.6. A 3.0.5 instance impersonating v9 sends the same field as an integer, which is what
    // FileTaskPayloadTests.recordedV9 was recorded from. Both forms have to decode: an Int-backed
    // Tagged rejecting the string used to throw and fail the whole page.
    let relatedDocument: Document.Id?

    let result: String?

    let status: String

    let taskFileName: String?

    let taskName: String?
}

extension FileTaskPayloadV9 {

    private enum CodingKeys: String, CodingKey {
        case acknowledged, dateCreated, dateDone, id, relatedDocument, result, status, taskFileName, taskName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acknowledged = try container.decode(Bool.self, forKey: .acknowledged)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        dateDone = try container.decodeIfPresent(Date.self, forKey: .dateDone)
        id = try container.decode(FileTask.Id.self, forKey: .id)
        relatedDocument = Self.decodeRelatedDocument(from: container)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        status = try container.decode(String.self, forKey: .status)
        taskFileName = try container.decodeIfPresent(String.self, forKey: .taskFileName)
        taskName = try container.decodeIfPresent(String.self, forKey: .taskName)
    }

    // Absent, null, or a non-numeric string all mean "no related document" rather than a decode
    // failure - one row must never be able to take the whole page down with it.
    private static func decodeRelatedDocument(from container: KeyedDecodingContainer<CodingKeys>) -> Document.Id? {
        if let id = try? container.decode(Document.Id.self, forKey: .relatedDocument) {
            return id
        }
        if let string = try? container.decode(String.self, forKey: .relatedDocument), let value = Int(string) {
            return Document.Id(rawValue: value)
        }
        return nil
    }
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
