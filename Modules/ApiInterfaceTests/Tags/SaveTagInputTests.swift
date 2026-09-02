@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveTagInputTests {
    @Test
    func encode() async throws {
        let token = SaveTagInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(token), as: UTF8.self)

        expectNoDifference(json, """
        {
          "color" : "#F7CE46",
          "is_inbox_tag" : true,
          "is_insensitive" : true,
          "match" : "",
          "matching_algorithm" : 6,
          "name" : "Inbox",
          "owner" : 1,
          "set_permissions" : {
            "change" : {
              "groups" : [
                1,
                2,
                3
              ],
              "users" : [
                4,
                5,
                6
              ]
            },
            "view" : {
              "groups" : [
                7,
                8,
                9
              ],
              "users" : [
                10,
                11,
                12
              ]
            }
          }
        }
        """)
    }
}
