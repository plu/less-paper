import ApiInterface
import SwiftSharing

public struct DocumentFilter: Equatable {

    var input = DocumentFilterInput()

    /// Whether this filter is the Inbox tab's.
    ///
    /// An inbox filter with no inbox tags produces *no* tag rule, which is indistinguishable from
    /// an unfiltered list in `input` alone — the list uses this to tell "the inbox is empty" apart
    /// from "show me everything".
    var isInbox = false

    var savedView: SavedView?

    /**
     * Builds the Inbox tab's filter from the tags the server reports as inbox tags.
     *
     * The ids come from the statistics response rather than the cached tags' `isInboxTag` flag:
     * statistics is re-read after every mutation, on foreground and on pull-to-refresh, so it
     * notices a tag being flagged as an inbox tag long before the tag cache would. The tags cache
     * still supplies the `Tag` values, because the selection holds tags rather than ids.
     *
     * - Parameter server: The server whose inbox tags to filter by.
     */
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
