import ApiInterface
import Foundation
import SwiftSharing

extension DocumentRowReducer.State {

    static func testValue(
        destination: DocumentRowReducer.Destination.State? = nil,
        document: Document = .testValue(),
        isUpdating: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            isUpdating: isUpdating,
            server: server
        )
    }
}
