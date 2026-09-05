import ApiInterface
import Foundation
import IdentifiedCollections

extension CorrespondentListReducer.State {

    static func testValue(
        correspondents: [Correspondent] = [],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            correspondents: IdentifiedArray(
                uniqueElements: correspondents.map {
                    CorrespondentRowReducer.State(
                        server: server,
                        correspondent: $0
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
