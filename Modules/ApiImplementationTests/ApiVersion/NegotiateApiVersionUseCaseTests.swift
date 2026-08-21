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
        var apiVersion: Int

        try await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 10 }
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
        var apiVersion: Int

        try await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 12 }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
        }

        #expect(apiVersion == ApiVersion.clientMaximum)
    }

    @Test
    func execute_throwsAndLeavesTheCacheAloneForAServerBelowTheFloor() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 6 }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(6)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }

        #expect(apiVersion == ApiVersion.minimumSupported)
    }

    @Test
    func execute_throwsWhenTheServerAdvertisesNothing() async throws {
        let server = Server.testValue()

        await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in nil }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(nil)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }
    }
}
