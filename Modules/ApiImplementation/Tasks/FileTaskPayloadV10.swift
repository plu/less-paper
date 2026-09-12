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

    private enum CodingKeys: String, CodingKey {
        case acknowledged, dateCreated, dateDone, id, inputData, relatedDocumentIds, resultData, status
    }

    // Hand-rolled for one key: related_document_ids defaults to empty rather than failing the row,
    // and a failed row on a v10 page fails the whole page with it. Everything else here that can
    // plausibly be absent is already optional.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acknowledged = try container.decode(Bool.self, forKey: .acknowledged)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        dateDone = try container.decodeIfPresent(Date.self, forKey: .dateDone)
        id = try container.decode(FileTask.Id.self, forKey: .id)
        inputData = try container.decodeIfPresent(JSONValue.self, forKey: .inputData)
        relatedDocumentIds = try container.decodeIfPresent([Document.Id].self, forKey: .relatedDocumentIds) ?? []
        resultData = try container.decodeIfPresent(JSONValue.self, forKey: .resultData)
        status = try container.decode(String.self, forKey: .status)
    }

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

    // `configureForApi` sets convertFromSnakeCase, but that strategy never reaches inside a decoded
    // [String: JSONValue] - it decodes through the stdlib Dictionary conformance, which Foundation
    // exempts from key conversion - so the server's `document_id` stays snake_case. Confirmed by the
    // recorded fixture at FileTaskPayloadTests.swift:212.
    private var documentId: Document.Id? {
        let fromResult = resultData?.objectValue?["document_id"]?.intValue

        if let fromResult {
            return Document.Id(rawValue: fromResult)
        }
        return relatedDocumentIds.first
    }

    // No failed consume task could be recorded to learn the real key from, so nothing is assumed.
    // Three tiers, narrowest first: a string under one of the keys paperless plausibly uses, then
    // any string in the object, then the raw JSON. That last tier is the point of the whole thing -
    // this screen exists to say what happened, and a failed row with nothing beside it is the one
    // outcome it must not be able to produce. Only an absent or empty result_data leaves the message
    // nil, so a success's `{"document_id": 43}` maps to that JSON; nothing displays it, because the
    // view shows a message on failed rows only.
    private var message: String? {
        guard let object = resultData?.objectValue else {
            return resultData?.stringValue
        }
        guard !object.isEmpty else {
            return nil
        }
        let preferred = ["error", "errors", "message", "detail", "reason", "result"]
            .lazy
            .compactMap { object[$0]?.stringValue }
            .first
        if let preferred {
            return preferred
        }
        // Sorted only to be deterministic: with none of the likely keys present there is no way to
        // tell which of several strings is the explanation, so the order here is arbitrary by
        // admission rather than by accident.
        let anyString = object
            .sorted { $0.key < $1.key }
            .compactMap { $0.value.stringValue }
            .first
        return anyString ?? rawResultData
    }

    // Sorted keys so the same payload always renders the same string - an unsorted dictionary would
    // make this message, and any test or snapshot over it, differ between runs.
    private var rawResultData: String? {
        guard let resultData else {
            return nil
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(resultData) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
