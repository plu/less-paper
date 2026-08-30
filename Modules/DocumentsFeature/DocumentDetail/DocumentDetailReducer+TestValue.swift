import ApiInterface
import Foundation
import SwiftSharing

extension DocumentDetailReducer.State {

    static func testValue(
        destination: DocumentDetailReducer.Destination.State? = nil,
        document: Document = .testValue(),
        downloadResult: DownloadResult? = nil,
        isOfflineSnapshot: Bool = false,
        isTogglingFavorite: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            downloadResult: downloadResult,
            isOfflineSnapshot: isOfflineSnapshot,
            isTogglingFavorite: isTogglingFavorite,
            server: server
        )
    }
}
