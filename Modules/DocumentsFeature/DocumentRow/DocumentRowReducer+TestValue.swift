import ApiInterface
import Components
import Foundation
import SwiftSharing

extension DocumentRowReducer.State {

    static func testValue(
        destination: DocumentRowReducer.Destination.State? = nil,
        document: Document = .testValue(),
        downloadedURL: URL? = nil,
        isDownloading: Bool = false,
        isUpdating: Bool = false,
        quickLookPreview: URL? = nil,
        server: Server = .testValue(),
        shareItem: ShareItem? = nil
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            downloadedURL: downloadedURL,
            isDownloading: isDownloading,
            isUpdating: isUpdating,
            quickLookPreview: quickLookPreview,
            server: server,
            shareItem: shareItem
        )
    }
}
