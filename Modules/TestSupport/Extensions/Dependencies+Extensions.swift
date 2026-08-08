#if canImport(DependenciesTestSupport)

@testable import DependenciesTestSupport

import Dependencies
import Foundation
import Testing

public extension Trait where Self == _DependenciesTrait {
    static func dependencies(
        _ updateValues: @escaping @Sendable (inout DependencyValues) async throws -> Void = { _ in }
    ) -> Self {
        Self {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.calendar.timeZone = .gmt
            $0.date.now = Date(timeIntervalSince1970: 1234567890)
            $0.timeZone = .gmt
            $0.uuid = .incrementing
            try await updateValues(&$0)
        }
    }
}

#endif
