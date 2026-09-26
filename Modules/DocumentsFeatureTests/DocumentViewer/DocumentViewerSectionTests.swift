@testable import DocumentsFeature

import Testing

@Suite
struct DocumentViewerSectionTests {

    @Test
    func visible_everythingAllowed() {
        #expect(DocumentViewerSection.visible(canViewHistory: true, canViewNotes: true) == [
            .content, .customFields, .history, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsHistory() {
        #expect(DocumentViewerSection.visible(canViewHistory: false, canViewNotes: true) == [
            .content, .customFields, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsNotes() {
        #expect(DocumentViewerSection.visible(canViewHistory: true, canViewNotes: false) == [
            .content, .customFields, .history, .metadata,
        ])
    }

    @Test
    func visible_dropsBoth() {
        #expect(DocumentViewerSection.visible(canViewHistory: false, canViewNotes: false) == [
            .content, .customFields, .metadata,
        ])
    }
}
