@testable import DocumentsFeature

import Testing

@Suite
struct DocumentSheetSectionTests {

    @Test
    func visible_everythingAllowed() {
        #expect(DocumentSheetSection.visible(isEditable: true, canViewHistory: true, canViewNotes: true) == [
            .content, .customFields, .details, .history, .metadata, .notes,
        ])
    }

    // Details exists to change the fields, so a user who cannot is not offered it at all.
    @Test
    func visible_dropsDetailsWhenNotEditable() {
        #expect(DocumentSheetSection.visible(isEditable: false, canViewHistory: true, canViewNotes: true) == [
            .content, .customFields, .history, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsHistory() {
        #expect(DocumentSheetSection.visible(isEditable: true, canViewHistory: false, canViewNotes: true) == [
            .content, .customFields, .details, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsNotes() {
        #expect(DocumentSheetSection.visible(isEditable: true, canViewHistory: true, canViewNotes: false) == [
            .content, .customFields, .details, .history, .metadata,
        ])
    }

    @Test
    func visible_dropsEverythingOptional() {
        #expect(DocumentSheetSection.visible(isEditable: false, canViewHistory: false, canViewNotes: false) == [
            .content, .customFields, .metadata,
        ])
    }
}
