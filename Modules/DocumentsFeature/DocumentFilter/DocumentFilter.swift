import ApiInterface
import SwiftSharing

public struct DocumentFilter: Equatable {

    var input = DocumentFilterInput()

    var savedView: SavedView?

    public static func inbox(server: Server) -> Self {
        @Shared(.tags(server))
        var tags

        var filter = Self()
        filter.input.tag = .init(
            rule: .any,
            selection: .init(
                any: Set(tags.filter(\.isInboxTag))
            )
        )
        return filter
    }
}

extension DocumentFilter {
    static func testValue(
        input: DocumentFilterInput = .testValue(),
        savedView: SavedView? = nil
    ) -> Self {
        .init(
            input: input,
            savedView: savedView
        )
    }
}
