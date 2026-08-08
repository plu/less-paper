import ApiInterface
import Foundation

extension DocumentTypeRowReducer.State {

    static func testValue(
        documentType: DocumentType = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            documentType: documentType,
            server: server
        )
    }
}
