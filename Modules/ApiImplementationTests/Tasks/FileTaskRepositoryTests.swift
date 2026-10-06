@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct FileTaskRepositoryTests {

    @Test
    func acknowledgeFileTasks_returnsVoid() async throws {
        try await repository.acknowledgeFileTasks(
            [1, 2],
            .testValue()
        )
    }

    @Test
    func getFailedFileTaskCountV10_returnsTestValue() async throws {
        let count = try await repository.getFailedFileTaskCountV10(
            .testValue()
        )

        #expect(count == 0)
    }

    @Test
    func getFailedFileTaskPayloadsV9_returnsTestValue() async throws {
        let payloads = try await repository.getFailedFileTaskPayloadsV9(
            .testValue()
        )

        #expect(payloads.isEmpty)
    }

    @Test
    func getFileTasksV10_returnsTestValue() async throws {
        let output = try await repository.getFileTasksV10(
            .failed,
            1,
            .testValue()
        )

        #expect(output.results.isEmpty)
    }

    @Test
    func getFileTasksV9_returnsTestValue() async throws {
        let payloads = try await repository.getFileTasksV9(
            .testValue()
        )

        #expect(payloads.isEmpty)
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getFileTasksV10_decodes() async throws {
        let page = try await repository.getFileTasksV10(
            .failed,
            1,
            .testValue()
        )

        #expect(page.count >= page.results.count)
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getFailedFileTaskCountV10_decodes() async throws {
        let count = try await repository.getFailedFileTaskCountV10(
            .testValue()
        )

        #expect(count >= 0)
    }

    @Dependency(\.fileTaskRepository)
    private var repository
}
