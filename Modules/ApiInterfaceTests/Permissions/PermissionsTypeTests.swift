@testable import ApiInterface

import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct PermissionsTypeTests {

    @Test
    func path() async throws {
        let type = PermissionsType.tag(id: 17)

        #expect(type.path == "/api/tags/17/")
    }
}
