@testable import Components

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentSwipeActionTests {

    @Test
    func onlyDeleteIsDestructive() async throws {
        let destructive = DocumentSwipeAction.allCases.filter(\.isDestructive)

        #expect(destructive == [.delete])
    }

    // The raw value is what reaches disk, so renaming a case silently drops that action from every
    // stored configuration. `favorite` was renamed to `saveOffline` and is the one case that has
    // been: it survives only because `init(storedRawValue:)` translates it, which
    // `decodingTranslatesTheLegacyFavoriteRawValue` is what actually holds.
    @Test
    func rawValuesAreStable() async throws {
        #expect(DocumentSwipeAction.allCases.map(\.rawValue) == [
            "clearInboxTags",
            "delete",
            "edit",
            "openNotes",
            "saveOffline",
            "preview",
            "share"
        ])
    }

    @Test
    func everyActionHasAnIcon() async throws {
        #expect(DocumentSwipeAction.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }

    // Settings renders these in `allCases` order, so the case order is what a person reads. It was
    // alphabetical by label until `favorite` became `saveOffline`, which sorts after `preview` by
    // case name while the label it shows - "Offline" - belongs before it.
    @Test
    func configurableActionsReadAlphabetically() async throws {
        let labels = DocumentSwipeAction.configurable.map { String(localized: $0.localized) }

        #expect(labels == labels.sorted())
    }

    // The alias translates one spelling and nothing else. A value a newer build wrote must still
    // come back nil so it is dropped, rather than being folded onto whichever case the alias
    // happens to name.
    @Test
    func anUnknownStoredRawValueIsNotAliased() async throws {
        #expect(DocumentSwipeAction(storedRawValue: "teleport") == nil)
        #expect(DocumentSwipeAction(storedRawValue: "favorite") == .saveOffline)
        #expect(DocumentSwipeAction(storedRawValue: "share") == .share)
    }
}
