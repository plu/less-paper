import ApiInterface
import Foundation

extension DocumentDetailReducer.State {

    static func testValue(
        destination: DocumentDetailReducer.Destination.State? = nil,
        document: Document = .testValue(),
        downloadResult: DownloadResult? = nil,
        server: Server = .testValue()
    ) -> Self {
        .init(
            destination: destination,
            document: document,
            downloadResult: downloadResult,
            server: server
        )
    }
}
