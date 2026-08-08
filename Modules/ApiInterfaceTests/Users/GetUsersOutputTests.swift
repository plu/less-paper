@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetUsersOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "all": [
            1
          ],
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "date_joined": "0001-01-01T00:00:00.000Z",
              "email": "john@doe.com",
              "first_name": "John",
              "groups": [],
              "id": 1,
              "inherited_permissions": ["something_unknown"],
              "is_active": true,
              "is_mfa_enabled": true,
              "is_staff": true,
              "is_superuser": true,
              "last_name": "Doe",
              "user_permissions": ["something_unknown"],
              "username": "admin"
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetUsersOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue()]
        ))
    }
}
