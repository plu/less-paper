@testable import ApiImplementation

import ApiInterface

extension GroupsRepository {

    func deleteAll() async throws {
        let groups = try await getGroups(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for group in groups {
            try await deleteGroup(
                id: group,
                server: .testValue()
            )
        }
    }
}
