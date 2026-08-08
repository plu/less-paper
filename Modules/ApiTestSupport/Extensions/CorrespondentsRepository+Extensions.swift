@testable import ApiImplementation

import ApiInterface

extension CorrespondentsRepository {

    func deleteAll() async throws {
        let correspondents = try await getCorrespondents(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for correspondent in correspondents {
            try await deleteCorrespondent(
                id: correspondent,
                server: .testValue()
            )
        }
    }
}
