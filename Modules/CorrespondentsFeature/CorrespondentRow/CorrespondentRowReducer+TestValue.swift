import ApiInterface
import Foundation

extension CorrespondentRowReducer.State {

    static func testValue(
        correspondent: Correspondent = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server,
            correspondent: correspondent
        )
    }
}
