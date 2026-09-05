import ApiInterface
import Foundation
import IdentifiedCollections

extension SavedViewListReducer.State {

    static func testValue(
        savedViews: [SavedView] = [],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            savedViews: IdentifiedArray(
                uniqueElements: savedViews.map {
                    SavedViewRowReducer.State(
                        server: server,
                        savedView: $0
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
