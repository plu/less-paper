import ApiInterface
import Foundation
import IdentifiedCollections

extension StoragePathListReducer.State {

    static func testValue(
        storagePaths: [StoragePath] = [],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            storagePaths: IdentifiedArray(
                uniqueElements: storagePaths.map {
                    StoragePathRowReducer.State(
                        server: server,
                        storagePath: $0
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
