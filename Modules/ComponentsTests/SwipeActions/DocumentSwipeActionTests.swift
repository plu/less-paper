@testable import Components

import Foundation
import Testing

@Suite
struct DocumentSwipeActionTests {

    @Test
    func onlyDeleteIsDestructive() async throws {
        let destructive = DocumentSwipeAction.allCases.filter(\.isDestructive)

        #expect(destructive == [.delete])
    }

    // The raw value is what reaches disk, so renaming a case silently drops that action from every
    // stored configuration.
    @Test
    func rawValuesAreStable() async throws {
        #expect(DocumentSwipeAction.allCases.map(\.rawValue) == [
            "clearInboxTags",
            "delete",
            "edit",
            "favorite",
            "openNotes",
            "preview",
            "share"
        ])
    }

    @Test
    func everyActionHasAnIcon() async throws {
        #expect(DocumentSwipeAction.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
