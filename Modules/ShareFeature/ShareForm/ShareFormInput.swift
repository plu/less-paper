import ApiInterface
import Components
import Dependencies
import Foundation
import PDFKit

struct ShareFormInput: Equatable, Sendable {

    var archiveSerialNumber = ""

    var correspondent: Correspondent?

    var createdDate = Dependency(\.date.now).wrappedValue

    var documentType: DocumentType?

    var password = ""

    var shouldRememberPassword = false

    var storagePath: StoragePath?

    var tags = Set<Tag>()

    var title = ""
}

extension ShareFormInput {

    mutating func reset() {
        correspondent = nil
        documentType = nil
        storagePath = nil
        tags = []
    }
}

extension ShareFormInput {

    func apiValue(url: URL) -> CreateDocumentInput {
        .init(
            archiveSerialNumber: Int(archiveSerialNumber),
            correspondent: correspondent?.id,
            createdDate: createdDate,
            documentType: documentType?.id,
            storagePath: storagePath?.id,
            tags: tags.map(\.id),
            title: title,
            url: url
        )
    }
}
