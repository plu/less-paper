#if canImport(DependenciesTestSupport)

@testable import DependenciesTestSupport

import Dependencies
import Foundation
import Testing

// Named `testDependencies` rather than `dependencies` because `DependenciesTestSupport` declares
// its own `.dependencies` trait on the same constrained extension. Both are visible wherever this
// module is imported, and from Swift 6.3 the pair is ambiguous at every call site rather than
// resolving to this one.
public extension Trait where Self == _DependenciesTrait {
    static func testDependencies(
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
