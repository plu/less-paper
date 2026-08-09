import ApiInterface
import Foundation
import Tagged

extension DocumentType: DocumentBulkEditGenericValue {

    public static var editTitle: LocalizedStringResource {
        .editDocumentType
    }

    public static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .documentTypeBulkEditConfirmationAssign(name, documentCount)
    }

    public static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .documentTypeBulkEditConfirmationRemove(documentCount)
    }

    public static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedDocumentTypes.map { ($0.id, $0.documentCount) }
        )
    }

    public static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setDocumentType(.init(documentType: id))
    }
}
