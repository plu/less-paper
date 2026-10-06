@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct ApiVersionRepositoryTests {

    @Test
    func getServerVersions_returnsTestValue() async throws {
        let versions = try await repository.getServerVersions(
            .testValue()
        )

        #expect(versions.apiVersion == ApiVersion.clientMaximum)
        #expect(versions.paperlessVersion == "3.0.5")
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getServerVersions_advertisesASupportedVersion() async throws {
        let versions = try await repository.getServerVersions(
            .testValue()
        )

        let negotiated = try ApiVersion.negotiated(from: versions.apiVersion)
        #expect(negotiated >= ApiVersion.minimumSupported)
        #expect(versions.paperlessVersion?.isEmpty == false)
    }

    @Dependency(\.apiVersionRepository)
    private var repository
}
