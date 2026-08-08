import ApiInterface
import Foundation
import IdentifiedCollections

extension TagListReducer.State {

    static func testValue(
        isLoaded: Bool = true,
        server: Server = .testValue(),
        tags: [Tag] = []
    ) -> Self {
        .init(
            isLoaded: isLoaded,
            server: server,
            tags: IdentifiedArray(
                uniqueElements: tags.map {
                    TagRowReducer.State(
                        server: server,
                        tag: $0
                    )
                }
            )
        )
    }
}
