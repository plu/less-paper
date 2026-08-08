@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetTokenInputTests {
    @Test
    func encode() async throws {
        let token = GetTokenInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(token), as: UTF8.self)

        expectNoDifference(json, """
        {
          "password" : "T0PS3CR3T!!123",
          "username" : "admin"
        }
        """)
    }
}
