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
                        correspondent: $0,
                        server: server
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
