@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct GlobalSearchUseCaseTests {

    @Test
    func execute_passesTheQueryThrough() async throws {
        try await withDependencies {
            $0.globalSearchRepository.search = { input, _ in
                #expect(input.query == "manual")
                return .testValue(tags: [.testValue(id: 7, name: "Manual")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "manual",
                server: .testValue()
            )

            #expect(output.tags.map(\.name) == ["Manual"])
        }
    }

    // The search payload has no document_count, so a tag taken straight from it would carry 0 into
    // the filter sheet. The cached tag is the one with the real count.
    @Test
    func execute_resolvesEntitiesAgainstTheCache() async throws {
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag>

        $tags.withLock {
            $0 = [.testValue(documentCount: 12, id: 7, name: "Manual")]
        }

        try await withDependencies {
            $0.globalSearchRepository.search = { _, _ in
                .testValue(tags: [.testValue(documentCount: 0, id: 7, name: "Manual")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "manual",
                server: .testValue()
            )

            #expect(output.tags.map(\.documentCount) == [12])
        }
    }

    // A tag created since the cache was last refreshed still has to appear in the results.
    @Test
    func execute_keepsEntitiesTheCacheHasNotSeen() async throws {
        @Shared(.tags(.testValue()))
        var tags: IdentifiedArrayOf<ApiInterface.Tag>

        $tags.withLock { $0 = [] }

        try await withDependencies {
            $0.globalSearchRepository.search = { _, _ in
                .testValue(tags: [.testValue(id: 99, name: "Brand New")])
            }
        } operation: {
            let output = try await GlobalSearchUseCase.liveValue.execute(
                query: "brand",
                server: .testValue()
            )

            #expect(output.tags.map(\.name) == ["Brand New"])
        }
    }
}
