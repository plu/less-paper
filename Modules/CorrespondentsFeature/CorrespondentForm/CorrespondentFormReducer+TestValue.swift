import ApiInterface
import Foundation
import PermissionsFeature

public extension CorrespondentFormReducer.State {

    static func testValue(
        correspondent: Correspondent? = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            correspondent: correspondent,
            server: server
        )
    }
}
