import ApiInterface
import SwiftSharing

public struct DocumentFilter: Equatable {

    var input = DocumentFilterInput()

    var isInbox = false

    var savedView: SavedView?

    public static func inbox(server: Server) -> Self {
        @Shared(.inboxTags(server))
        var inboxTags

        @Shared(.tags(server))
        var tags

        var filter = Self()
        filter.isInbox = true
        filter.input.tag = .init(
            rule: .any,
            selection: .init(
                any: Set(inboxTags.compactMap { tags[id: $0] })
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
