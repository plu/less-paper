@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentFilterInboxTests {

    /// The tag *ids* come from the statistics response — refreshed on every mutation, foreground
    /// and pull-to-refresh — while the tags cache supplies the `Tag` values the selection holds.
    @Test
    func inbox_filtersByTheInboxTagsFromStatistics() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = [104]

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [
            .testValue(id: 104, isInboxTag: true, name: "Inbox"),
            .testValue(id: 200, isInboxTag: false, name: "Invoice"),
        ]

        let filter = DocumentFilter.inbox(server: server)

        #expect(filter.input.tag.selection.any.map(\.id) == [104])
        #expect(filter.input.filterRules == [.init(ruleType: .hasTagsAny, value: "104")])
        #expect(filter.isInbox)
    }

    /// A tag the server has newly flagged as an inbox tag is picked up from the statistics ids even
    /// though the cached `Tag` still says `isInboxTag == false`.
    @Test
    func inbox_prefersStatisticsIdsOverTheCachedFlag() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = [200]

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [
            .testValue(id: 104, isInboxTag: true, name: "Inbox"),
            .testValue(id: 200, isInboxTag: false, name: "Invoice"),
        ]

        let filter = DocumentFilter.inbox(server: server)

        #expect(filter.input.tag.selection.any.map(\.id) == [200])
    }

    /// An empty selection produces no tag rule at all, which would ask the server for *every*
    /// document. `isInbox` is what lets the list tell that apart from an unfiltered list.
    @Test
    func inbox_withoutInboxTags_isStillMarkedAsInbox() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = []

        let filter = DocumentFilter.inbox(server: server)

        #expect(filter.input.tag.selection.any.isEmpty)
        #expect(filter.input.filterRules == [])
        #expect(filter.isInbox)
    }

    @Test
    func defaultFilter_isNotInbox() async throws {
        #expect(!DocumentFilter().isInbox)
    }
}
