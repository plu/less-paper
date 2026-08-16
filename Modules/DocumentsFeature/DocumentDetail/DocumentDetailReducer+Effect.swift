import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentDetailReducer.Action {

    static func runDownloadDocument(document: Document, server: Server) -> Self {
        .run { send in
            let file = try await document.download(server: server)
            await send(.downloadResult(.success(data: file.data, url: file.url)), animation: .default)
        } catch: { error, send in
            await send(.downloadResult(.failure(error.localizedDescription)))
        }
        .cancellable(id: CancelID.downloadDocument)
    }
}

private enum CancelID {
    case downloadDocument
}
