@testable import ApiImplementation

import ApiInterface

extension TagsRepository {

    func deleteAll() async throws {
        let tags = try await getTags(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for tag in tags {
            try await deleteTag(
                id: tag,
                server: .testValue()
            )
        }
    }
}
