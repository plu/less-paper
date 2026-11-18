import Dependencies
import DependenciesMacros
import UIKit

@DependencyClient
struct PasteboardClient: Sendable {
    var copy: @Sendable (_ string: String) -> Void
}

extension PasteboardClient: DependencyKey {

    static let liveValue = Self(
        copy: { string in
            UIPasteboard.general.string = string
        }
    )

    static let previewValue = Self(
        copy: { _ in }
    )
}

extension DependencyValues {

    var pasteboard: PasteboardClient {
        get { self[PasteboardClient.self] }
        set { self[PasteboardClient.self] = newValue }
    }
}
