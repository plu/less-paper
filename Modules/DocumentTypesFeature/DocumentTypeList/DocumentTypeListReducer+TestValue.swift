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
                        server: server,
                        documentType: $0
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
