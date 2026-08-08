import Foundation
import Tagged

public struct GetSelectionDataOutput: Decodable, Equatable, Sendable {

    public let selectedCorrespondents: [SelectionDataItem<Correspondent.Id>]

    public let selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>]

    public let selectedStoragePaths: [SelectionDataItem<StoragePath.Id>]

    public let selectedTags: [SelectionDataItem<Tag.Id>]

    public init(
        selectedCorrespondents: [SelectionDataItem<Correspondent.Id>],
        selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>],
        selectedStoragePaths: [SelectionDataItem<StoragePath.Id>],
        selectedTags: [SelectionDataItem<Tag.Id>]
    ) {
        self.selectedCorrespondents = selectedCorrespondents
        self.selectedDocumentTypes = selectedDocumentTypes
        self.selectedStoragePaths = selectedStoragePaths
        self.selectedTags = selectedTags
    }
}

public extension GetSelectionDataOutput {

    static func testValue(
        selectedCorrespondents: [SelectionDataItem<Correspondent.Id>] = [.init(documentCount: 2, id: 1)],
        selectedDocumentTypes: [SelectionDataItem<DocumentType.Id>] = [.init(documentCount: 1, id: 2)],
        selectedStoragePaths: [SelectionDataItem<StoragePath.Id>] = [.init(documentCount: 3, id: 3)],
        selectedTags: [SelectionDataItem<Tag.Id>] = [.init(documentCount: 4, id: 4)]
    ) -> Self {
        .init(
            selectedCorrespondents: selectedCorrespondents,
            selectedDocumentTypes: selectedDocumentTypes,
            selectedStoragePaths: selectedStoragePaths,
            selectedTags: selectedTags
        )
    }
}
