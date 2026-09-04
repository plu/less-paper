import Dependencies
import DependenciesMacros
import Foundation
import Logging

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
        @Dependency(\.deviceContext)
        var deviceContext

        return [deviceContext.appVersion(), deviceContext.appBuild()]
            .joined(separator: "-")
    }
}

extension DependencyValues {
    var getAppVersion: GetAppVersionUseCase {
        get { self[GetAppVersionUseCase.self] }
        set { self[GetAppVersionUseCase.self] = newValue }
    }
}
