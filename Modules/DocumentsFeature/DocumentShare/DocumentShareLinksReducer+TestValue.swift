import ApiInterface
import Components
import Foundation
import IdentifiedCollections

extension DocumentShareLinksReducer.State {

    static func testValue(
        documentId: Document.Id = 1,
        expiry: DocumentShareLinksExpiry = .sevenDays,
        hasArchiveVersion: Bool = true,
        isCreating: Bool = false,
        links: IdentifiedArrayOf<ShareLink>? = nil,
        loadError: String? = nil,
        server: Server = .testValue(),
        shareArchiveVersion: Bool = true,
        shareItem: ShareItem? = nil
    ) -> Self {
        var state = Self(
            document: .testValue(
                archivedFileName: hasArchiveVersion ? "invoice.pdf" : nil,
                id: documentId
            ),
            server: server
        )
        state.expiry = expiry
        state.isCreating = isCreating
        state.links = links
        state.loadError = loadError
        state.shareArchiveVersion = shareArchiveVersion
        state.shareItem = shareItem
        return state
    }
}
