import ApiInterface
import Foundation

public protocol DocumentBulkEditGenericValue: CustomStringConvertible, Hashable, Identifiable, Sendable where ID: Sendable {

    static var editTitle: LocalizedStringResource { get }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [ID: Int]

    static func method(id: ID?) -> BulkEditDocumentsInput.Method
}
