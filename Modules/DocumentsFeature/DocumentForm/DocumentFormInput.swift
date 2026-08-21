import ApiInterface
import Dependencies
import Foundation

struct DocumentFormInput: Equatable, Sendable {

    var archiveSerialNumber = ""

    var correspondent: Correspondent?

    var createdDate: Date

    var documentType: DocumentType?

    var storagePath: StoragePath?

    var tags = Set<Tag>()

    var title = ""
}

extension DocumentFormInput {

    init(document: Document, server: Server) {
        if let archiveSerialNumber = document.archiveSerialNumber {
            self.archiveSerialNumber = String(archiveSerialNumber)
        }

        correspondent = document.correspondent?.get(server)
        createdDate = document.created
        documentType = document.documentType?.get(server)
        storagePath = document.storagePath?.get(server)
        tags = Set(document.tags.compactMap { $0.get(server) })
        title = document.title
    }

    func apiValue(content: String?) -> UpdateDocumentInput {
        .init(
            archiveSerialNumber: Int(archiveSerialNumber),
            content: content,
            correspondent: correspondent?.id,
            createdDate: createdDate,
            documentType: documentType?.id,
            storagePath: storagePath?.id,
            tags: tags.map(\.id),
            title: title
        )
    }
}
