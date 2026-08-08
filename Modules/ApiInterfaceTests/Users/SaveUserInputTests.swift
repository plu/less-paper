@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct SaveUserInputTests {

    @Test
    func encode() async throws {
        let input = SaveUserInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "email" : "jane@doe.com",
          "first_name" : "Jane",
          "groups" : [

          ],
          "is_active" : true,
          "is_staff" : true,
          "is_superuser" : true,
          "last_name" : "Doe",
          "password" : "T0PS3CR3T!!123",
          "user_permissions" : [

          ],
          "username" : "jdoe"
        }
        """)
    }
}
