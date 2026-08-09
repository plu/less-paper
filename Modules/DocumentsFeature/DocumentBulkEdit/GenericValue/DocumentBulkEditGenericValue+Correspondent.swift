import ApiInterface
import Foundation
import Tagged

extension Correspondent: DocumentBulkEditGenericValue {

    public static var editTitle: LocalizedStringResource {
        .editCorrespondent
    }

    public static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationAssign(name, documentCount)
    }

    public static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationRemove(documentCount)
    }

    public static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedCorrespondents.map { ($0.id, $0.documentCount) }
        )
    }

    public static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setCorrespondent(.init(correspondent: id))
    }
}
