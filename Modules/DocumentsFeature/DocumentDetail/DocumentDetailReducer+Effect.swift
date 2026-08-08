import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentDetailReducer.Action {

    static func runDownloadDocument(document: Document, server: Server) -> Self {
        @Dependency(\.downloadDocument.execute)
        var downloadDocument

        return .run { send in
            let data = try await downloadDocument(document.id, server)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(document.fileName)
            try data.write(to: url, options: .atomic)
            await send(.downloadResult(.success(data: data, url: url)), animation: .default)
        } catch: { error, send in
            await send(.downloadResult(.failure(error.localizedDescription)))
        }
        .cancellable(id: CancelID.downloadDocument)
    }
}

private enum CancelID {
    case downloadDocument
}
