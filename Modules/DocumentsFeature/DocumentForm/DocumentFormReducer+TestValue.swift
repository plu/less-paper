import ApiInterface
import Foundation
import SwiftSharing

extension DocumentFormReducer.State {

    static func testValue(
        destination: DocumentFormReducer.Destination.State? = nil,
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            server: server
        )
    }
}
