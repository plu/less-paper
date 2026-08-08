@testable import ApiImplementation

import ApiInterface

extension UsersRepository {

    func deleteAll() async throws {
        let users = try await getUsers(
            input: .testValue(),
            server: .testValue()
        ).results
        for user in users {
            if user.username == "admin" {
                continue
            }
            try await deleteUser(
                id: user.id,
                server: .testValue()
            )
        }
    }
}
