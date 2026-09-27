@testable import Components

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentSwipeActionSettingsTests {

    @Test
    func defaultsAreOpenDetailsOneWayAndShareTheOther() async throws {
        let settings = DocumentSwipeActionSettings()

        #expect(settings.leading == [.openDetails])
        #expect(settings.trailing == [.share])
    }

    // Clearing inbox tags is added for you, on any document that has them, so offering it as a
    // choice would be offering to turn off something that is not a choice.
    @Test
    func clearInboxTagsIsNotConfigurable() async throws {
        #expect(!DocumentSwipeAction.configurable.contains(.clearInboxTags))
        #expect(DocumentSwipeAction.configurable.count == DocumentSwipeAction.allCases.count - 1)
    }

    @Test
    func roundTripsThroughJSON() async throws {
        let settings = DocumentSwipeActionSettings(
            leading: [.openDetails, .preview],
            trailing: [.delete, .share]
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
        { "leading": ["teleport", "edit"], "trailing": ["share"] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.openDetails])
        #expect(decoded.trailing == [.share])
    }

    @Test
    func anEdgeOfOnlyUnknownActionsDecodesEmptyRatherThanThrowing() async throws {
        let json = Data("""
        { "leading": ["teleport"], "trailing": [] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading.isEmpty)
    }

    // The same "a newer build must not brick an older one" rule, one level up: a missing key would
    // otherwise throw and cost the user the whole preference rather than the part it cannot read.
    @Test
    func decodingToleratesMissingKeys() async throws {
        let json = Data("""
        { "leading": ["favorite"] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.saveOffline])
        // A missing edge falls back to its default rather than to nothing.
        #expect(decoded.trailing == DocumentSwipeActionSettings().trailing)
    }

    // `favorite` is what this case's raw value was before the feature was renamed to Offline, and
    // a configuration written by any shipped build still says it. Dropping it would not fail
    // loudly - the decode compactMaps - so the user's swipe would simply stop existing.
    @Test
    func decodingTranslatesTheLegacyFavoriteRawValue() async throws {
        let json = Data("""
        { "leading": ["favorite"], "trailing": ["share"] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.saveOffline])
    }

    // `edit` is what a shipped build wrote before the actions were per section, and the view- and
    // edit- pairs are what a build wrote before the sheet decided the mode itself. Each lands on
    // the section it opened, so the swipe keeps going where it went.
    @Test
    func decodingTranslatesEarlierPerSectionRawValues() async throws {
        let json = Data("""
        { "leading": ["edit", "viewHistory"], "trailing": ["editNotes", "viewContent"] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.openDetails, .openHistory])
        #expect(decoded.trailing == [.openNotes, .openContent])
    }

    // Both halves of a former pair name one section now, so an edge that held both keeps one.
    @Test
    func decodingCollapsesAViewAndEditPairIntoOneAction() async throws {
        let json = Data("""
        { "leading": ["viewContent", "editContent"], "trailing": [] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.openContent])
    }

    // A downgrade and an upgrade can leave both spellings in one edge, and the alias turns them
    // into the same case - which would draw the same button twice.
    @Test
    func decodingCollapsesTheLegacyAndCurrentSpellingsOfOneAction() async throws {
        let json = Data("""
        { "leading": ["favorite", "saveOffline"], "trailing": [] }
        """.utf8)

        let decoded = try JSONDecoder().decode(DocumentSwipeActionSettings.self, from: json)

        #expect(decoded.leading == [.saveOffline])
    }
}
