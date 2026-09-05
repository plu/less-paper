import ApiInterface
import Foundation

extension StoragePathRowReducer.State {

    static func testValue(
        storagePath: StoragePath = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server,
            storagePath: storagePath
        )
    }
}
