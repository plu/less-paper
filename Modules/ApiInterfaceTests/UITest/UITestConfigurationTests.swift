@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct UITestConfigurationTests {

    @Test
    func roundTripsSeededConfiguration() async throws {
        let configuration = UITestConfiguration(
            seed: .init(
                password: "secret",
                server: .testValue(),
                token: "abc123"
            )
        )

        let environment = [
            UITestConfiguration.environmentKey: try configuration.environmentValue()
        ]

        expectNoDifference(
            UITestConfiguration.fromEnvironment(environment),
            configuration
        )
    }

    @Test
    func roundTripsCleanSlateConfiguration() async throws {
        let configuration = UITestConfiguration()

        let environment = [
            UITestConfiguration.environmentKey: try configuration.environmentValue()
        ]

        expectNoDifference(
            UITestConfiguration.fromEnvironment(environment),
            configuration
        )
    }

    @Test
    func returnsNilWhenKeyAbsent() async throws {
        #expect(UITestConfiguration.fromEnvironment([:]) == nil)
    }

    @Test
    func returnsNilWhenPayloadMalformed() async throws {
        #expect(
            UITestConfiguration.fromEnvironment(
                [UITestConfiguration.environmentKey: "not json"]
            ) == nil
        )
    }
}
