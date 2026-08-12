import ApiInterface
import Foundation
import SwiftSharing

extension DocumentRowReducer.State {

    static func testValue(
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            document: Shared(value: document),
            server: server
        )
    }
}
