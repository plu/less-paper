import ApiInterface
import Foundation

extension DocumentSearchReducer.State {

    static func testValue(
        error: String? = nil,
        isGlobalSearchEnabled: Bool = true,
        isLoading: Bool = false,
        results: GlobalSearchOutput? = nil,
        searchText: String = "",
        server: Server = .testValue()
    ) -> Self {
        .init(
            error: error,
            isGlobalSearchEnabled: isGlobalSearchEnabled,
            isLoading: isLoading,
            results: results,
            searchText: searchText,
            server: server
        )
    }
}
