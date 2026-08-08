import ApiInterface
import Foundation

extension TagRowReducer.State {

    static func testValue(
        server: Server = .testValue(),
        tag: Tag = .testValue()
    ) -> Self {
        .init(
            server: server,
            tag: tag
        )
    }
}
