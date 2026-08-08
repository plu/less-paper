import ApiInterface
import Foundation

extension DocumentFilterReducer.State {

    static func testValue(
        destination: DocumentFilterReducer.Destination.State? = nil,
        input: DocumentFilterInput = .testValue(),
        savedView: SavedView? = nil,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            input: input,
            savedView: savedView,
            server: server
        )
    }
}
