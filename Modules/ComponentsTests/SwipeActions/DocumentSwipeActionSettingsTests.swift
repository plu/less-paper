@testable import Components

import Foundation
import Testing

@Suite
struct DocumentSwipeActionSettingsTests {

    @Test
    func defaultsAreEditLeadingAndClearInboxTrailingOnBothScreens() async throws {
        let settings = DocumentSwipeActionSettings()

        #expect(settings.inbox.leading == [.edit])
        #expect(settings.inbox.trailing == [.clearInboxTags])
        #expect(settings.documents.leading == [.edit])
        #expect(settings.documents.trailing == [.clearInboxTags])
    }

    @Test
    func roundTripsThroughJSON() async throws {
        let settings = DocumentSwipeActionSettings(
            documents: .init(leading: [.favorite], trailing: [.delete, .share]),
            inbox: .init(leading: [.edit, .preview], trailing: [.clearInboxTags])
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: data)

        #expect(decoded == settings)
    }

    // A configuration written by a newer build must cost the user the one action this build cannot
    // name, not the whole preference.
    @Test
    func decodingDropsUnknownActionsAndKeepsTheRest() async throws {
        let json = Data("""
        {
          "documents": { "leading": ["edit"], "trailing": ["share"] },
          "inbox": { "leading": ["teleport", "edit"], "trailing": ["clearInboxTags"] }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.inbox.leading == [.edit])
        #expect(decoded.inbox.trailing == [.clearInboxTags])
        #expect(decoded.documents.leading == [.edit])
        #expect(decoded.documents.trailing == [.share])
    }

    @Test
    func anEdgeOfOnlyUnknownActionsDecodesEmptyRatherThanThrowing() async throws {
        let json = Data("""
        {
          "documents": { "leading": ["teleport"], "trailing": [] },
          "inbox": { "leading": [], "trailing": [] }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.documents.leading.isEmpty)
    }
}
