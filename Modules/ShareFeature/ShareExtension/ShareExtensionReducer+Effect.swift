import ApiInterface
import ComposableArchitecture
import Dependencies
import Foundation

extension Effect where Action == ShareExtensionReducer.Action {

    static func dismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runLoadItems(
        extensionContext: NSExtensionContext
    ) -> Self {
        @Dependency(\.copyFiles.execute)
        var copyFiles

        let attachments = UncheckedSendable(
            extensionContext
                .inputItems
                .compactMap { $0 as? NSExtensionItem }
                .compactMap(\.attachments)
                .flatMap(\.self)
        )

        return .run { send in
            await send(.certificateApproval(.bootstrap))
            await send(.set(\.isLoading, true))
            let urls = try await copyFiles(loadItems(attachments: attachments))
            await send(.filesLoaded(urls))
            await send(.set(\.isLoading, false))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoading, false))
        }
    }

    static func runLoadItems(
        files: [URL]
    ) -> Self {
        @Dependency(\.copyFiles.execute)
        var copyFiles

        return .run { send in
            await send(.certificateApproval(.bootstrap))
            await send(.set(\.isLoading, true))
            try await send(.filesLoaded(copyFiles(files)))
            await send(.set(\.isLoading, false))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoading, false))
        }
    }

    private static func loadItems(attachments: UncheckedSendable<[NSItemProvider]>) async throws -> [URL] {
        var urls: [URL] = []

        for attachment in attachments.value {
            if let url = try? await attachment.getURL() {
                urls.append(url)
            }
        }
        return urls
    }
}
