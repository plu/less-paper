import Foundation

public struct SelectionDataItem<Id: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {

    public let documentCount: Int

    public let id: Id

    public init(
        documentCount: Int,
        id: Id
    ) {
        self.documentCount = documentCount
        self.id = id
    }
}
