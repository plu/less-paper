@testable import ApiImplementation

import ApiInterface

extension StoragePathsRepository {

    func deleteAll() async throws {
        let storagePaths = try await getStoragePaths(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for storagePath in storagePaths {
            try await deleteStoragePath(
                id: storagePath,
                server: .testValue()
            )
        }
    }
}
