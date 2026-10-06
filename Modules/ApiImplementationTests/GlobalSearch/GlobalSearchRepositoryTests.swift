@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct GlobalSearchRepositoryTests {

    @Test
    func search_returnsTestValue() async throws {
        let output = try await repository.search(
            input: .init(query: "manual"),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_search_decodes() async throws {
        let output = try await repository.search(
            input: .init(query: "Lego"),
            server: .testValue()
        )

        #expect(!output.documents.isEmpty)
    }

    @Dependency(\.globalSearchRepository)
    private var repository
}
