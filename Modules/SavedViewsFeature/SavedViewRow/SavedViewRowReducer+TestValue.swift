import ApiInterface
import Foundation

extension SavedViewRowReducer.State {

    static func testValue(
        savedView: SavedView = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server,
            savedView: savedView
        )
    }
}
