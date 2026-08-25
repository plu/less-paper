import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections

struct DocumentFormInput: Equatable, Sendable {

    var archiveSerialNumber = ""

    var correspondent: Correspondent?

    var createdDate: Date

    var customFields = IdentifiedArrayOf<DocumentFormCustomField>()

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
        customFields = IdentifiedArray(
            uniqueElements: document.customFields.compactMap { stored in
                guard let field = stored.field.get(server) else {
                    return nil
                }
                return DocumentFormCustomField(
                    id: field.id,
                    value: DocumentFormCustomFieldValue(field: field, json: stored.value)
                )
            }
        )
        documentType = document.documentType?.get(server)
        storagePath = document.storagePath?.get(server)
        tags = Set(document.tags.compactMap { $0.get(server) })
        title = document.title
    }

    var hasInvalidCustomField: Bool {
        customFields.contains { $0.value.validationError != nil }
    }

    func apiValue(content: String?, server: Server) -> UpdateDocumentInput {
        .init(
            archiveSerialNumber: Int(archiveSerialNumber),
            content: content,
            correspondent: correspondent?.id,
            createdDate: createdDate,
            customFields: customFields.compactMap { row in
                guard let field = row.id.get(server) else {
                    return nil
                }
                return DocumentCustomField(field: field.id, value: row.value.json(field: field))
            },
            documentType: documentType?.id,
            storagePath: storagePath?.id,
            tags: tags.map(\.id),
            title: title
        )
    }
}
