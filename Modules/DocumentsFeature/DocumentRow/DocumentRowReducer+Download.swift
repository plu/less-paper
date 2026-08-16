import Components
import ComposableArchitecture
import Foundation

extension DocumentRowReducer.State {

    mutating func download(intent: DocumentRowReducer.DownloadIntent) -> Effect<DocumentRowReducer.Action> {
        guard let downloadedURL else {
            isDownloading = true
            return .runDownloadDocument(document: document, intent: intent, server: server)
        }
        present(url: downloadedURL, intent: intent)
        return .none
    }

    mutating func present(url: URL, intent: DocumentRowReducer.DownloadIntent) {
        switch intent {
        case .preview:
            quickLookPreview = url
        case .share:
            shareItem = ShareItem(url: url)
        }
    }
}
