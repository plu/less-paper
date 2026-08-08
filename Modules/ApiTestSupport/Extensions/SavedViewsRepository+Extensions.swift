@testable import ApiImplementation

import ApiInterface

extension SavedViewsRepository {

    func deleteAll() async throws {
        let savedViews = try await getSavedViews(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for savedView in savedViews {
            try await deleteSavedView(
                id: savedView,
                server: .testValue()
            )
        }
    }
}
