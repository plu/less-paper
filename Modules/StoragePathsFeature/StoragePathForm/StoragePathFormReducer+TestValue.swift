import ApiInterface
import Foundation
import PermissionsFeature

public extension StoragePathFormReducer.State {

    static func testValue(
        storagePath: StoragePath? = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            storagePath: storagePath,
            server: server
        )
    }
}
