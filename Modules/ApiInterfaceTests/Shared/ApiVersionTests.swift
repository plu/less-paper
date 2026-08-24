@testable import ApiInterface

import Foundation
import Testing

@Suite
struct ApiVersionTests {

    @Test
    func negotiated_clampsAServerAheadOfTheClientToTheClientMaximum() throws {
        #expect(try ApiVersion.negotiated(from: 11) == 10)
    }

    @Test
    func negotiated_acceptsTheClientMaximum() throws {
        #expect(try ApiVersion.negotiated(from: 10) == 10)
    }

    @Test
    func negotiated_acceptsTheFloor() throws {
        #expect(try ApiVersion.negotiated(from: 8) == 8)
    }

    @Test
    func negotiated_acceptsAVersionBetweenTheFloorAndTheClientMaximum() throws {
        #expect(try ApiVersion.negotiated(from: 9) == 9)
    }

    @Test
    func negotiated_rejectsAServerBelowTheFloor() {
        #expect(throws: ApiVersionError.unsupportedServer(7)) {
            try ApiVersion.negotiated(from: 7)
        }
    }

    // A server old enough to predate ApiVersionMiddleware sends no X-Api-Version at all. That is
    // indistinguishable from "too old" and must not be treated as "assume the floor".
    @Test
    func negotiated_rejectsAMissingAdvertisedVersion() {
        #expect(throws: ApiVersionError.unsupportedServer(nil)) {
            try ApiVersion.negotiated(from: nil)
        }
    }

    @Test
    func errorDescription_namesTheServersVersionWhenKnown() {
        let description = ApiVersionError.unsupportedServer(6).errorDescription

        #expect(description?.contains("6") == true)
        #expect(description?.contains("8") == true)
    }

    @Test
    func errorDescription_isPresentWhenTheVersionIsUnknown() {
        #expect(ApiVersionError.unsupportedServer(nil).errorDescription?.isEmpty == false)
    }
}
