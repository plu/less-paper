@testable import ApiInterface

import Foundation
import Testing

@Suite
struct UISettingsTests {

    // Captured from /api/ui_settings/ on a live instance. Note what user does NOT contain: no
    // date_joined, email, first_name, last_name, is_active, is_mfa_enabled, user_permissions or
    // inherited_permissions. That absence is why User is five fields.
    @Test
    func decodesTheCapturedPayload() throws {
        let json = """
        {
          "user": {
            "id": 40,
            "username": "permtest",
            "is_staff": false,
            "is_superuser": false,
            "groups": []
          },
          "settings": { "version": "2.18.4" },
          "permissions": ["view_document", "view_uisettings"]
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.user.id == 40)
        #expect(settings.user.username == "permtest")
        #expect(settings.user.isSuperuser == false)
        #expect(settings.permissions == [.viewDocument, .viewUiSettings])
    }

    // A newer paperless sends codenames this enum does not know. Skipping them keeps a server
    // upgrade from making the app undecodable - and an unknown permission is one the app cannot gate
    // on anyway, which fails open, which is correct.
    @Test
    func skipsUnknownPermissionStrings() throws {
        let json = """
        {
          "user": { "id": 1, "username": "a", "is_staff": false, "is_superuser": false, "groups": [] },
          "settings": {},
          "permissions": ["view_document", "invent_teleporter"]
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.permissions == [.viewDocument])
    }

    // An older paperless may not send the key at all. That is "unknown", not "none" - and the
    // difference decides whether the app shows every control or hides every control.
    @Test
    func absentPermissionsKeyDecodesToNilRatherThanEmpty() throws {
        let json = """
        {
          "user": { "id": 1, "username": "a", "is_staff": false, "is_superuser": false, "groups": [] },
          "settings": {}
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.permissions == nil)
    }
}
