import ApiInterface
import ComposableArchitecture
import Dependencies
import Foundation
import Logging
import PDFKit

extension Effect where Action == ShareFormReducer.Action {

    static func runGetNextArchiveSerialNumber(server: Server) -> Self {
        .run { send in
            @Dependency(\.getNextArchiveSerialNumber.execute)
            var getNextArchiveSerialNumber
            await send(.set(\.isLoadingNextArchiveSerialNumber, true))
            try await send(.nextArchiveSerialNumber(getNextArchiveSerialNumber(server)))
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        } catch: { error, send in
            @Dependency(\.log)
            var log
            log.error(error, category: .share)
            await send(.set(\.isLoadingNextArchiveSerialNumber, false))
        }
    }

    // Silent by design. Every stored password failing is the expected outcome for a document the
    // user has never unlocked, so this reports nothing and lets the unlock form appear.
    // Takes only the URL, never the caller's PDFDocument: the passwords have to be awaited from the
    // keychain first, and PDFDocument is not Sendable, so it cannot cross into this closure. Reading
    // a fresh copy here is also what `.fileUnlocked` does afterwards.
    static func runAutoUnlock(
        url: URL
    ) -> Self {
        .run { send in
            @Dependency(\.getPdfPasswords.execute)
            var getPdfPasswords

            guard let document = PDFDocument(url: url) else {
                return
            }

            for stored in try await getPdfPasswords() {
                guard document.unlock(withPassword: stored.password) else {
                    continue
                }
                guard document.write(
                    to: url,
                    withOptions: [.ownerPasswordOption: "", .userPasswordOption: ""]
                )
                else {
                    return
                }
                await send(.fileUnlocked, animation: .snappy)
                return
            }
        } catch: { error, _ in
            // Nothing is shown for this one, so without the log an unlock failure leaves no trace
            // anywhere at all.
            @Dependency(\.log)
            var log
            log.error(error, category: .share)
        }
    }

    static func runUnlockFile(
        document: PDFDocument?,
        filename: String,
        password: String,
        shouldRemember: Bool,
        url: URL
    ) -> Self {
        guard let document, document.unlock(withPassword: password) == true else {
            return .send(.error(ShareFormError.unlockFailed))
        }

        guard document.write(
            to: url,
            withOptions: [.ownerPasswordOption: "", .userPasswordOption: ""]
        ) == true
        else {
            return .send(.error(ShareFormError.unlockFailed))
        }

        return .run { send in
            if shouldRemember {
                @Dependency(\.savePdfPassword.execute)
                var savePdfPassword

                // Best effort: a keychain write failing must not block an unlock the user has
                // already completed.
                try? await savePdfPassword(filename, password)
            }
            await send(.fileUnlocked, animation: .snappy)
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
            // An SSO login inside a memory-constrained extension is a bad place to be, and the
            // main app is one tap away. Translate the bounce to a dedicated error so the toast
            // names the actual remedy rather than showing a raw network failure.
            if case ForwardAuthError.required = error {
                await send(.error(ShareFormError.forwardAuthRequired))
                await send(.set(\.isImporting, false))
                return
            }
            await send(.error(error))
            await send(.set(\.isImporting, false))
        }
    }
}
