import ApiInterface
import Foundation

extension DocumentFormReducer.State {

    static func testValue(
        destination: DocumentFormReducer.Destination.State? = nil,
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: document,
            server: server
        )
    }
}
