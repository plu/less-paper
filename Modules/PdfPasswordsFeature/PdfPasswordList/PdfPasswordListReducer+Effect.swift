import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == PdfPasswordListReducer.Action {

    static func runGetPdfPasswords() -> Self {
        @Dependency(\.getPdfPasswords.execute)
        var getPdfPasswords

        return .run { send in
            await send(.getPdfPasswordsResult(try await getPdfPasswords()))
        } catch: { error, send in
            await send(.error(error))
        }
    }

    static func runDeletePdfPassword(id: String) -> Self {
        @Dependency(\.deletePdfPassword.execute)
        var deletePdfPassword

        return .run { send in
            try await deletePdfPassword(id)
            await send(.pdfPasswordDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
        }
    }
}
