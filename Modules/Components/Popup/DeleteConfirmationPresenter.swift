import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteConfirmationPresenter: Sendable {
    public var present: @Sendable (
        _ title: LocalizedStringResource,
        _ name: String
    ) async -> Bool = { _, _ in false }
}

extension DeleteConfirmationPresenter: TestDependencyKey {

    public static let previewValue = Self(
        present: { _, _ in false }
    )

    public static let testValue = Self()
}

extension DeleteConfirmationPresenter: DependencyKey {

    public static let liveValue = Self(
        present: present(title:name:)
    )
}

private extension DeleteConfirmationPresenter {

    static func present(title: LocalizedStringResource, name: String) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: title,
                message: .deleteConfirmation(name),
                isDestructive: true,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }
}

public extension DependencyValues {

    var deleteConfirmation: DeleteConfirmationPresenter {
        get { self[DeleteConfirmationPresenter.self] }
        set { self[DeleteConfirmationPresenter.self] = newValue }
    }
}
