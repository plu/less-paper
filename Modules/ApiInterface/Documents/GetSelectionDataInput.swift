import Foundation
import Tagged

public struct GetSelectionDataInput: Encodable, Equatable, Sendable {

    public let documents: [Document.Id]

    public init(documents: [Document.Id]) {
        self.documents = documents
    }
}

public extension GetSelectionDataInput {

    static func testValue(
        documents: [Document.Id] = [1, 2, 3]
    ) -> Self {
        .init(documents: documents)
    }
}
