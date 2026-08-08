import ApiInterface
import Foundation
import PermissionsFeature

public extension DocumentTypeFormReducer.State {

    static func testValue(
        documentType: DocumentType? = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            documentType: documentType,
            server: server
        )
    }
}
