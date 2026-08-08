import ApiInterface
import Foundation
import IdentifiedCollections

extension DocumentTypeListReducer.State {

    static func testValue(
        documentTypes: [DocumentType] = [],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            documentTypes: IdentifiedArray(
                uniqueElements: documentTypes.map {
                    DocumentTypeRowReducer.State(
                        documentType: $0,
                        server: server
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
