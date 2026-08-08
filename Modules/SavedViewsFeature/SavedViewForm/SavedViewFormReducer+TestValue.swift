import ApiInterface
import Foundation
import PermissionsFeature

public extension SavedViewFormReducer.State {

    static func testValue(
        id: SavedView.Id? = nil,
        input: SavedViewFormInput = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            id: id,
            input: input,
            server: server
        )
    }
}
