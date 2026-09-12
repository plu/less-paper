import Foundation
import Tagged

public struct FileTask: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<FileTask, Int>

    public let dateCreated: Date

    public let dateDone: Date?

    public let documentId: Document.Id?

    public let fileName: String?

    public let id: Id

    public let isAcknowledged: Bool

    // Whatever the server said about the outcome. v9 sends prose even on success, v10 sends nothing
    // at all there, so this is mapped as it arrives and only the failed rows display it.
    public let message: String?

    public let status: FileTaskStatus

    public init(
        dateCreated: Date,
        dateDone: Date?,
        documentId: Document.Id?,
        fileName: String?,
        id: Id,
        isAcknowledged: Bool,
        message: String?,
        status: FileTaskStatus
    ) {
        self.dateCreated = dateCreated
        self.dateDone = dateDone
        self.documentId = documentId
        self.fileName = fileName
        self.id = id
        self.isAcknowledged = isAcknowledged
        self.message = message
        self.status = status
    }
}

public extension FileTask {

    static func testValue(
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        documentId: Document.Id? = 42,
        fileName: String? = "invoice.pdf",
        id: Id = 1,
        isAcknowledged: Bool = false,
        message: String? = nil,
        status: FileTaskStatus = .complete
    ) -> Self {
        .init(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: documentId,
            fileName: fileName,
            id: id,
            isAcknowledged: isAcknowledged,
            message: message,
            status: status
        )
    }
}
