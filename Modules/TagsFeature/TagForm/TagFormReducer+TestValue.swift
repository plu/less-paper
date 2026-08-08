import ApiInterface
import Foundation
import PermissionsFeature

public extension TagFormReducer.State {

    static func testValue(
        server: Server = .testValue(),
        tag: Tag? = .testValue()
    ) -> Self {
        .init(
            server: server,
            tag: tag
        )
    }
}
