import ApiInterface
import Foundation

extension ServerListReducer.State {

    static func testValue(
        destination: ServerListReducer.Destination.State? = nil
    ) -> Self {
        .init(
            destination: destination
        )
    }
}
