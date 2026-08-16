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
    // `inbox(server:)` is not usable from tests: it reads `@Shared(.inboxTags(server))` and
    // `@Shared(.tags(server))`, so a test using it would depend on shared storage rather than on
    // the state it is trying to describe.
    static func testValue(
        input: DocumentFilterInput = .testValue(),
        isInbox: Bool = false,
        savedView: SavedView? = nil
    ) -> Self {
        var filter = Self(
            input: input,
            savedView: savedView
        )
        filter.isInbox = isInbox
        return filter
    }
}
