import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct UISettingsRepository: Sendable {

    var getUISettings: @Sendable (
        _ input: GetUISettingsInput,
        _ server: Server
    ) async throws -> GetUISettingsOutput

    var updateUISettings: @Sendable (
        _ input: UpdateUISettingsInput,
        _ server: Server
    ) async throws -> UpdateUISettingsOutput
}

extension UISettingsRepository: TestDependencyKey {
    static let previewValue = Self(
        getUISettings: { _, _ in .testValue() },
        updateUISettings: { _, _ in .testValue() }
    )

    static let testValue = Self(
        getUISettings: { _, _ in .testValue() },
        updateUISettings: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var uiSettingsRepository: UISettingsRepository {
        get { self[UISettingsRepository.self] }
        set { self[UISettingsRepository.self] = newValue }
    }
}

extension UISettingsRepository: DependencyKey {
    static let liveValue = Self(
        getUISettings: getUISettings(input:server:),
        updateUISettings: updateUISettings(input:server:)
    )
}

private extension UISettingsRepository {

    static func getUISettings(
        input: GetUISettingsInput,
        server: Server
    ) async throws -> GetUISettingsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/ui_settings/",
                method: .get
            ))
            .value
    }

    static func updateUISettings(
        input: UpdateUISettingsInput,
        server: Server
    ) async throws -> UpdateUISettingsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/ui_settings/",
                method: .post,
                body: input
            ))
            .value
    }
}
