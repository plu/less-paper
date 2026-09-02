@testable import ApiInterface

import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SaveGroupOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "id": 1,
          "name": "Admins",
          "permissions": [
            "add_applicationconfiguration",
            "add_correspondent",
            "add_customfield",
            "add_document",
            "add_documenttype",
            "add_group",
            "add_logentry",
            "add_mailaccount",
            "add_mailrule",
            "add_note",
            "add_paperlesstask",
            "add_savedview",
            "add_sharelink",
            "add_storagepath",
            "add_tag",
            "add_uisettings",
            "add_user",
            "add_workflow",
            "change_applicationconfiguration",
            "change_correspondent",
            "change_customfield",
            "change_document",
            "change_documenttype",
            "change_group",
            "change_logentry",
            "change_mailaccount",
            "change_mailrule",
            "change_note",
            "change_paperlesstask",
            "change_savedview",
            "change_sharelink",
            "change_storagepath",
            "change_tag",
            "change_uisettings",
            "change_user",
            "change_workflow",
            "delete_applicationconfiguration",
            "delete_correspondent",
            "delete_customfield",
            "delete_document",
            "delete_documenttype",
            "delete_group",
            "delete_logentry",
            "delete_mailaccount",
            "delete_mailrule",
            "delete_note",
            "delete_paperlesstask",
            "delete_savedview",
            "delete_sharelink",
            "delete_storagepath",
            "delete_tag",
            "delete_uisettings",
            "delete_user",
            "delete_workflow",
            "view_applicationconfiguration",
            "view_correspondent",
            "view_customfield",
            "view_document",
            "view_documenttype",
            "view_group",
            "view_logentry",
            "view_mailaccount",
            "view_mailrule",
            "view_note",
            "view_paperlesstask",
            "view_savedview",
            "view_sharelink",
            "view_storagepath",
            "view_tag",
            "view_uisettings",
            "view_user",
            "view_workflow"
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(SaveGroupOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue())
    }
}
