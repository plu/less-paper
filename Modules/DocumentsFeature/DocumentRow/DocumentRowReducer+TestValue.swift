import ApiInterface
import Foundation

extension DocumentRowReducer.State {

    static func testValue(
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            document: document,
            server: server
        )
    }
}
