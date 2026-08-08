@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct AuthenticationRepositoryTests {

    @Test
    func getToken_returnsTestValue() async throws {
        let output = try await repository.getToken(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func getToken_returnsLiveValue() async throws {
        let output = try await repository.getToken(
            input: .testValue(),
            server: .testValue()
        )

        #expect(output.token.isEmpty == false)
    }

    @Test(
        .dependencies {
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func getToken_returnsApiError() async throws {
        let error = await #expect(throws: ApiError.self) {
            try await repository.getToken(
                input: .testValue(password: "wrong password"),
                server: .testValue()
            )
        }

        #expect(error == .testValue(errors: ["Unable to log in with provided credentials."]))
    }

    @Dependency(\.authenticationRepository)
    private var repository
}
