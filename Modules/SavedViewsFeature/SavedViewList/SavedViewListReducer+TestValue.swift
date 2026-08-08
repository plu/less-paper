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
                        savedView: $0,
                        server: server
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
