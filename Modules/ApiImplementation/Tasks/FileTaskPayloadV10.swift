import ApiInterface
import Foundation

typealias FileTaskListOutputV10 = ListOutput<FileTaskPayloadV10, FileTask.Id>

// GET /api/tasks/ as answered by API version 10: paginated, and with the interesting parts moved into
// two free-form JSON objects. `inputData` carries the file name, `resultData` the outcome.
struct FileTaskPayloadV10: Codable, Equatable, Sendable {

    let acknowledged: Bool

    let dateCreated: Date

    let dateDone: Date?

    let id: FileTask.Id

    let inputData: JSONValue?

    let relatedDocumentIds: [Document.Id]

    let resultData: JSONValue?

    let status: String
}

extension FileTaskPayloadV10 {

    var asFileTask: FileTask {
        FileTask(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: documentId,
            fileName: inputData?.objectValue?["filename"]?.stringValue,
            id: id,
            isAcknowledged: acknowledged,
            message: message,
            status: FileTaskStatus(apiValue: status) ?? .queued
        )
    }

    // `configureForApi` sets convertFromSnakeCase, which rewrites the keys inside a decoded
    // [String: JSONValue] as well - so the server's `document_id` arrives as `documentId`. Both
    // spellings are accepted rather than betting on that behaviour surviving a Foundation update.
    private var documentId: Document.Id? {
        let fromResult = resultData?.objectValue?["documentId"]?.intValue
            ?? resultData?.objectValue?["document_id"]?.intValue

        if let fromResult {
            return Document.Id(rawValue: fromResult)
        }
        return relatedDocumentIds.first
    }

    // No failed consume task could be recorded to learn the real key from, so nothing is assumed:
    // the first string in the object is the message. A success has none, which is correct - only
    // failed rows show this.
    private var message: String? {
        guard let object = resultData?.objectValue else {
            return resultData?.stringValue
        }
        return object
            .sorted { $0.key < $1.key }
            .compactMap { $0.value.stringValue }
            .first
    }
}
