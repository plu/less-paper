@testable import ApiImplementation

import ApiInterface
import Foundation
import TestSupport

extension FileTaskPayloadV9 {

    static func testValue(
        acknowledged: Bool = false,
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        id: FileTask.Id = 1,
        relatedDocument: Document.Id? = 42,
        result: String? = nil,
        status: String = "SUCCESS",
        taskFileName: String? = "invoice.pdf",
        taskName: String? = "consume_file"
    ) -> Self {
        .init(
            acknowledged: acknowledged,
            dateCreated: dateCreated,
            dateDone: dateDone,
            id: id,
            relatedDocument: relatedDocument,
            result: result,
            status: status,
            taskFileName: taskFileName,
            taskName: taskName
        )
    }
}

extension FileTaskPayloadV10 {

    static func testValue(
        acknowledged: Bool = false,
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        id: FileTask.Id = 1,
        inputData: JSONValue? = .object(["filename": .string("invoice.pdf")]),
        relatedDocumentIds: [Document.Id] = [42],
        resultData: JSONValue? = nil,
        status: String = "success"
    ) -> Self {
        .init(
            acknowledged: acknowledged,
            dateCreated: dateCreated,
            dateDone: dateDone,
            id: id,
            inputData: inputData,
            relatedDocumentIds: relatedDocumentIds,
            resultData: resultData,
            status: status
        )
    }
}
