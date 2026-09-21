import ApiInterface
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import StoragePathsFeature
import TagsFeature

// Each of these replaces the filter rather than adding to it, which is what the web client does and
// what keeps the result of a tap describable in one line: documents that have this thing.
extension DocumentFilterInput {

    static func searchResult(correspondent: Correspondent) -> Self {
        var input = Self()
        input.correspondent.rule = .include
        input.correspondent.selection = [correspondent]
        return input
    }

    static func searchResult(customField: CustomField) -> Self {
        var input = Self()
        input.customFieldQuery = .atom(.init(field: customField.id, op: .exists, value: .bool(true)))
        return input
    }

    static func searchResult(documentType: DocumentType) -> Self {
        var input = Self()
        input.documentType.rule = .include
        input.documentType.selection = [documentType]
        return input
    }

    static func searchResult(storagePath: StoragePath) -> Self {
        var input = Self()
        input.storagePath.rule = .include
        input.storagePath.selection = [storagePath]
        return input
    }

    static func searchResult(tag: Tag) -> Self {
        var input = Self()
        input.tag.rule = .any
        input.tag.selection.any = [tag]
        return input
    }
}
