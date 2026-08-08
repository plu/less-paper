@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct UISettingsRepositoryTests {

    @Test
    func getUISettings_returnsTestValue() async throws {
        let output = try await repository.getUISettings(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getUISettings() async throws {
        let uiSettings = try await repository.getUISettings(
            input: .testValue(),
            server: .testValue()
        )

        #expect(uiSettings.settings.version.isEmpty == false)
        #expect(uiSettings.user.id > 0)
    }

    @Test
    func updateUISettings_returnsTestValue() async throws {
        let output = try await repository.updateUISettings(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Dependency(\.uiSettingsRepository)
    private var repository
}
