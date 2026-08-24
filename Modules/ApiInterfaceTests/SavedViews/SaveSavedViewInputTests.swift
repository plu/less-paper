@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveSavedViewInputTests {
    @Test
    func encode() async throws {
        let token = SaveSavedViewInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(token), as: UTF8.self)

        expectNoDifference(json, """
        {
          "filter_rules" : [

          ],
          "name" : "Test SavedView",
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
          },
          "sort_field" : "added",
          "sort_reverse" : true
        }
        """)
    }

    @Test
    func encode_withVisibility() async throws {
        let input = SaveSavedViewInput.testValue(showInSidebar: true, showOnDashboard: false)

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "filter_rules" : [

          ],
          "name" : "Test SavedView",
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
          },
          "show_in_sidebar" : true,
          "show_on_dashboard" : false,
          "sort_field" : "added",
          "sort_reverse" : true
        }
        """)
    }
}
