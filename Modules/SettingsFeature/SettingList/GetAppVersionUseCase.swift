import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct GetAppVersionUseCase: Sendable {
    var execute: @Sendable () -> String = { "1.0.0-1" }
}

extension GetAppVersionUseCase: TestDependencyKey {
    static let previewValue = Self(execute: { "1.0.0-1" })

    static let testValue = Self(execute: { "1.0.0-1" })
}

extension GetAppVersionUseCase: DependencyKey {
    public static let liveValue = Self(
        execute: execute
    )
}

private extension GetAppVersionUseCase {
    static func execute() -> String {
        [
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        ]
        .compactMap(\.self).joined(separator: "-")
    }
}

extension DependencyValues {
    var getAppVersion: GetAppVersionUseCase {
        get { self[GetAppVersionUseCase.self] }
        set { self[GetAppVersionUseCase.self] = newValue }
    }
}
