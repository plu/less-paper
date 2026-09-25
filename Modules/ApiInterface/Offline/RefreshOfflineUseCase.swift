import Dependencies
import DependenciesMacros
import Foundation

public struct OfflineRefreshResult: Equatable, Sendable {

    public let failed: Int

    public let unavailable: Int

    public let updated: Int

    public init(failed: Int = 0, unavailable: Int = 0, updated: Int = 0) {
        self.failed = failed
        self.unavailable = unavailable
        self.updated = updated
    }
}

@DependencyClient
public struct RefreshOfflineUseCase: Sendable {

    // `force` is what separates pull-to-refresh from Settings' "Redownload all": the same walk,
    // with phase two run for every offline document instead of only the changed ones.
    public var execute: @Sendable (
        _ force: Bool,
        _ server: Server
    ) async throws -> OfflineRefreshResult
}

extension RefreshOfflineUseCase: TestDependencyKey {

    public static let previewValue = Self(execute: { _, _ in .init() })

    public static let testValue = Self(execute: { _, _ in .init() })
}

public extension DependencyValues {

    var refreshOffline: RefreshOfflineUseCase {
        get { self[RefreshOfflineUseCase.self] }
        set { self[RefreshOfflineUseCase.self] = newValue }
    }
}

// One identity for every refresh, whichever module triggers it. Pull-to-refresh in the tab and the
// launch and foreground refreshes in AppFeature walk the same records and write the same PDF paths,
// so two of them at once means downloading everything twice. It lives beside the use case because
// both modules already depend on it and neither can see the other's cancel ids.
public enum RefreshOfflineCancelID: Sendable {
    case refresh
}
