@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetUISettingsOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "permissions": [
            "add_savedviewfilterrule",
            "add_emailconfirmation",
            "delete_workflowrun",
            "view_socialtoken",
            "view_customfield",
            "delete_workflow",
            "add_session",
            "add_socialaccount",
            "add_mailaccount",
            "view_tag",
            "view_savedviewfilterrule",
            "change_correspondent",
            "change_workflowtrigger",
            "delete_mailaccount",
            "delete_socialapp",
            "delete_group",
            "change_socialaccount",
            "change_savedviewfilterrule",
            "add_sharelink",
            "change_workflowrun",
            "add_emailaddress",
            "delete_workflowactionemail",
            "delete_customfield",
            "view_chordcounter",
            "change_workflowactionwebhook",
            "add_logentry",
            "delete_note",
            "delete_logentry",
            "delete_tokenproxy",
            "view_note",
            "change_paperlesstask",
            "view_workflowactionwebhook",
            "add_logentry",
            "add_paperlesstask",
            "change_chordcounter",
            "delete_groupresult",
            "add_groupresult",
            "change_user",
            "view_paperlesstask",
            "view_taskresult",
            "view_session",
            "delete_token",
            "view_groupobjectpermission",
            "delete_workflowtrigger",
            "change_socialtoken",
            "view_mailaccount",
            "add_workflowactionemail",
            "view_emailconfirmation",
            "add_authenticator",
            "delete_permission",
            "delete_session",
            "delete_socialaccount",
            "view_workflowaction",
            "add_savedview",
            "delete_tag",
            "change_documenttype",
            "add_taskresult",
            "add_document",
            "delete_user",
            "add_storagepath",
            "change_customfield",
            "delete_storagepath",
            "change_workflow",
            "delete_emailaddress",
            "view_applicationconfiguration",
            "view_logentry",
            "view_documenttype",
            "delete_customfieldinstance",
            "change_authenticator",
            "view_group",
            "delete_workflowactionwebhook",
            "delete_documenttype",
            "delete_chordcounter",
            "add_workflowactionwebhook",
            "add_socialtoken",
            "change_tokenproxy",
            "add_chordcounter",
            "change_document",
            "add_user",
            "change_workflowaction",
            "view_uisettings",
            "change_logentry",
            "view_log",
            "change_group",
            "view_savedview",
            "change_token",
            "add_note",
            "delete_logentry",
            "add_mailrule",
            "view_groupresult",
            "view_processedmail",
            "view_document",
            "add_tokenproxy",
            "change_log",
            "delete_groupobjectpermission",
            "view_sharelink",
            "add_tag",
            "delete_socialtoken",
            "add_applicationconfiguration",
            "delete_savedviewfilterrule",
            "change_socialapp",
            "delete_log",
            "view_socialaccount",
            "view_token",
            "view_mailrule",
            "delete_sharelink",
            "view_workflowtrigger",
            "change_emailaddress",
            "change_applicationconfiguration",
            "view_workflowrun",
            "add_groupobjectpermission",
            "change_groupresult",
            "add_customfield",
            "change_groupobjectpermission",
            "delete_workflowaction",
            "add_workflowrun",
            "view_workflow",
            "add_documenttype",
            "delete_savedview",
            "delete_paperlesstask",
            "delete_contenttype",
            "view_customfieldinstance",
            "delete_processedmail",
            "change_customfieldinstance",
            "add_userobjectpermission",
            "delete_document",
            "delete_userobjectpermission",
            "change_permission",
            "add_uisettings",
            "change_workflowactionemail",
            "change_uisettings",
            "change_mailaccount",
            "view_authenticator",
            "delete_applicationconfiguration",
            "delete_authenticator",
            "change_emailconfirmation",
            "view_user",
            "add_permission",
            "add_token",
            "view_correspondent",
            "add_workflow",
            "delete_taskresult",
            "add_log",
            "change_contenttype",
            "view_workflowactionemail",
            "change_mailrule",
            "change_session",
            "add_processedmail",
            "change_savedview",
            "add_socialapp",
            "view_tokenproxy",
            "change_note",
            "add_correspondent",
            "view_socialapp",
            "change_sharelink",
            "delete_emailconfirmation",
            "change_tag",
            "view_storagepath",
            "view_permission",
            "add_workflowtrigger",
            "view_logentry",
            "delete_uisettings",
            "add_workflowaction",
            "add_contenttype",
            "view_userobjectpermission",
            "change_userobjectpermission",
            "change_processedmail",
            "add_customfieldinstance",
            "change_logentry",
            "delete_correspondent",
            "delete_mailrule",
            "change_taskresult",
            "view_contenttype",
            "view_emailaddress",
            "change_storagepath",
            "add_group"
          ],
          "settings": {
            "app_logo": null,
            "app_title": null,
            "auditlog_enabled": true,
            "bulk_edit": {
              "apply_on_close": false,
              "confirmation_dialogs": true
            },
            "dark_mode": {
              "enabled": "false",
              "thumb_inverted": "true",
              "use_system": true
            },
            "date_display": {
              "date_format": "mediumDate",
              "date_locale": ""
            },
            "documentListSize": 50,
            "document_details": {
              "native_pdf_viewer": false,
              "pdf_viewer_zoom_setting": "page-width"
            },
            "document_editing": {
              "overlay_thumbnail": true,
              "remove_inbox_tags": false
            },
            "email_enabled": false,
            "language": "de-de",
            "notes_enabled": true,
            "notifications": {
              "consumer_failed": true,
              "consumer_new_documents": true,
              "consumer_success": true,
              "consumer_suppress_on_dashboard": true
            },
            "permissions": {
              "default_edit_groups": [],
              "default_edit_users": [],
              "default_owner": 3,
              "default_view_groups": [],
              "default_view_users": []
            },
            "saved_views": {
              "sidebar_views_show_count": true,
              "warn_on_unsaved_change": true
            },
            "search": {
              "db_only": false,
              "more_link": "title-content"
            },
            "slim_sidebar": false,
            "theme": {
              "color": ""
            },
            "trash_delay": 30,
            "update_checking": {
              "backend_setting": "default",
              "enabled": false
            },
            "version": "2.18.4"
          },
          "user": {
            "groups": [],
            "id": 1,
            "is_staff": true,
            "is_superuser": true,
            "username": "admin"
          }
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetUISettingsOutput.self, from: #require(json.data(using: .utf8)))

        #expect(output.user.id == 1)
        #expect(output.settings.version == "2.18.4")
        #expect(output.settings.savedViews?.dashboardViewsVisibleIds == [])
        #expect(output.settings.savedViews?.sidebarViewsVisibleIds == [])
        expectNoDifference(output.settings.raw["slim_sidebar"], .bool(false))
        expectNoDifference(output.settings.raw["trash_delay"], .number(30))
    }

    @Test
    func decode_v10_savedViewVisibility() async throws {
        let json = """
        {
          "user": {
            "id": 2,
            "username": "admin",
            "is_staff": true,
            "is_superuser": true,
            "groups": []
          },
          "settings": {
            "version": "3.0.0",
            "saved_views": {
              "dashboard_views_visible_ids": [
                4
              ],
              "sidebar_views_visible_ids": [
                4
              ]
            }
          }
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetUISettingsOutput.self, from: #require(json.data(using: .utf8)))

        #expect(output.settings.savedViews?.dashboardViewsVisibleIds == [4])
        #expect(output.settings.savedViews?.sidebarViewsVisibleIds == [4])
    }

    @Test
    func encode_decode_roundTrip_preservesUnknownKeys() async throws {
        let settings = UISettings.Settings(raw: [
            "theme": .object(["color": .string("dark")]),
            "trash_delay": .number(30),
            "saved_views": .object([
                "sidebar_views_show_count": .bool(true)
            ])
        ])
        let uiSettings = UISettings.testValue(settings: settings)

        let data = try JSONEncoder.apiEncoder.encode(uiSettings)
        let decoded = try JSONDecoder.apiDecoder.decode(UISettings.self, from: data)

        expectNoDifference(decoded, uiSettings)
    }
}
