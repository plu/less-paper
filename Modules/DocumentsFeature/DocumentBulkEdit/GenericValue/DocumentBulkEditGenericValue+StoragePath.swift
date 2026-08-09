import ApiInterface
import Foundation
import Tagged

extension StoragePath: DocumentBulkEditGenericValue {

    public static var editTitle: LocalizedStringResource {
        .editStoragePath
    }

    public static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .storagePathBulkEditConfirmationAssign(name, documentCount)
    }

    public static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .storagePathBulkEditConfirmationRemove(documentCount)
    }

    public static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedStoragePaths.map { ($0.id, $0.documentCount) }
        )
    }

    public static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setStoragePath(.init(storagePath: id))
    }
}
