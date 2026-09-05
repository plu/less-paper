import ApiInterface
import Foundation

extension DocumentTypeRowReducer.State {

    static func testValue(
        documentType: DocumentType = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server,
            documentType: documentType
        )
    }
}
