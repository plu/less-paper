@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct SaveStoragePathInputTests {
    @Test
    func encode() async throws {
        let token = SaveStoragePathInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(token), as: UTF8.self)

        expectNoDifference(json, """
        {
          "is_insensitive" : true,
          "match" : "",
          "matching_algorithm" : 6,
          "name" : "Test StoragePath",
          "owner" : 1,
          "path" : "\\/home\\/paperless\\/test-storagepath",
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
