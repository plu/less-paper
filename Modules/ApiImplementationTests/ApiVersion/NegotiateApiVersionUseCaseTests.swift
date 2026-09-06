@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct NegotiateApiVersionUseCaseTests {

    @Test
    func execute_storesTheAdvertisedVersion() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in ServerVersions(apiVersion: 10, paperlessVersion: nil) }
        } operation: {
            let negotiated = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            #expect(negotiated == 10)
        }

        #expect(apiVersion == 10)
    }

    @Test
    func execute_clampsAServerAheadOfTheClient() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in ServerVersions(apiVersion: 12, paperlessVersion: nil) }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
        }

        #expect(apiVersion == ApiVersion.clientMaximum)
    }

    @Test
    func execute_throwsAndLeavesTheCacheAloneForAServerBelowTheFloor() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?

        await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in ServerVersions(apiVersion: 6, paperlessVersion: nil) }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(6)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }

        #expect(apiVersion == nil)
    }

    @Test
    func execute_throwsWhenTheServerAdvertisesNothing() async throws {
        let server = Server.testValue()

        await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in ServerVersions(apiVersion: nil, paperlessVersion: nil) }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(nil)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }
    }

    @Test
    func negotiateStoresBothVersions() async throws {
        let server = Server.testValue()

        @Shared(.apiVersion(server)) var apiVersion: Int?
        @Shared(.paperlessVersion(server)) var paperlessVersion: String?

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in
                ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: "3.0.5")
            }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
        }

        #expect(apiVersion == ApiVersion.clientMaximum)
        #expect(paperlessVersion == "3.0.5")
    }

    // A server that sends no X-Version must leave the key nil rather than keeping a stale value,
    // so the screen can say "unknown" instead of reporting a version that is no longer true.
    @Test
    func negotiateClearsThePaperlessVersionWhenTheHeaderIsAbsent() async throws {
        let server = Server.testValue()

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "3.0.5" }

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in
                ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: nil)
            }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
        }

        #expect(paperlessVersion == nil)
    }
}
