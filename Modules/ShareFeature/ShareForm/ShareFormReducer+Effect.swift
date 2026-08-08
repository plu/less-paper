import ApiInterface
import ComposableArchitecture
import Dependencies
import Foundation
import PDFKit

extension Effect where Action == ShareFormReducer.Action {

    static func runGetNextArchiveSerialNumber(server: Server) -> Self {
        .run { send in
            @Dependency(\.getNextArchiveSerialNumber.execute)
            var getNextArchiveSerialNumber
            await send(.set(\.isLoadingNextArchiveSerialNumber, true))
            try await send(.nextArchiveSerialNumber(getNextArchiveSerialNumber(server)))
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        } catch: { _, send in
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        }
    }

    static func runUnlockFile(
        document: PDFDocument?,
        password: String,
        url: URL
    ) -> Self {
        guard let document, document.unlock(withPassword: password) == true else {
            return .send(.error(ShareFormError.unlockFailed))
        }

        if document.write(
            to: url,
            withOptions: [.ownerPasswordOption: "", .userPasswordOption: ""]
        ) == true {
            return .run { send in
                await send(.fileUnlocked, animation: .snappy)
            }
        } else {
            return .send(.error(ShareFormError.unlockFailed))
        }
    }

    static func runUploadFile(
        input: ShareFormInput,
        server: Server,
        url: URL
    ) -> Self {
        .run { send in
            @Dependency(\.createDocument.execute)
            var createDocument
            await send(.set(\.isImporting, true))
            try await createDocument(input.apiValue(url: url), server)
            await send(.set(\.isImporting, false))
            await send(.fileImported)
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isImporting, false))
        }
    }
}
