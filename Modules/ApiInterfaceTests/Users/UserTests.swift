@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct UserTests {

    @Test
    func decode_superuser() async throws {
        let json = """
        {
          "date_joined": "2025-10-27T11:06:47.856959+01:00",
          "email": "",
          "first_name": "",
          "groups": [
            2
          ],
          "id": 21,
          "inherited_permissions": [
            "account.add_emailaddress",
            "account.add_emailconfirmation",
            "account.change_emailaddress",
            "account.change_emailconfirmation",
            "account.delete_emailaddress",
            "account.delete_emailconfirmation",
            "account.view_emailaddress",
            "account.view_emailconfirmation",
            "admin.add_logentry",
            "admin.change_logentry",
            "admin.delete_logentry",
            "admin.view_logentry",
            "auditlog.add_logentry",
            "auditlog.change_logentry",
            "auditlog.delete_logentry",
            "auditlog.view_logentry",
            "auth.add_group",
            "auth.add_permission",
            "auth.add_user",
            "auth.change_group",
            "auth.change_permission",
            "auth.change_user",
            "auth.delete_group",
            "auth.delete_permission",
            "auth.delete_user",
            "auth.view_group",
            "auth.view_permission",
            "auth.view_user",
            "authtoken.add_token",
            "authtoken.add_tokenproxy",
            "authtoken.change_token",
            "authtoken.change_tokenproxy",
            "authtoken.delete_token",
            "authtoken.delete_tokenproxy",
            "authtoken.view_token",
            "authtoken.view_tokenproxy",
            "contenttypes.add_contenttype",
            "contenttypes.change_contenttype",
            "contenttypes.delete_contenttype",
            "contenttypes.view_contenttype",
            "django_celery_results.add_chordcounter",
            "django_celery_results.add_groupresult",
            "django_celery_results.add_taskresult",
            "django_celery_results.change_chordcounter",
            "django_celery_results.change_groupresult",
            "django_celery_results.change_taskresult",
            "django_celery_results.delete_chordcounter",
            "django_celery_results.delete_groupresult",
            "django_celery_results.delete_taskresult",
            "django_celery_results.view_chordcounter",
            "django_celery_results.view_groupresult",
            "django_celery_results.view_taskresult",
            "documents.add_correspondent",
            "documents.add_customfield",
            "documents.add_customfieldinstance",
            "documents.add_document",
            "documents.add_documenttype",
            "documents.add_log",
            "documents.add_note",
            "documents.add_paperlesstask",
            "documents.add_savedview",
            "documents.add_savedviewfilterrule",
            "documents.add_sharelink",
            "documents.add_storagepath",
            "documents.add_tag",
            "documents.add_uisettings",
            "documents.add_workflow",
            "documents.add_workflowaction",
            "documents.add_workflowactionemail",
            "documents.add_workflowactionwebhook",
            "documents.add_workflowrun",
            "documents.add_workflowtrigger",
            "documents.change_correspondent",
            "documents.change_customfield",
            "documents.change_customfieldinstance",
            "documents.change_document",
            "documents.change_documenttype",
            "documents.change_log",
            "documents.change_note",
            "documents.change_paperlesstask",
            "documents.change_savedview",
            "documents.change_savedviewfilterrule",
            "documents.change_sharelink",
            "documents.change_storagepath",
            "documents.change_tag",
            "documents.change_uisettings",
            "documents.change_workflow",
            "documents.change_workflowaction",
            "documents.change_workflowactionemail",
            "documents.change_workflowactionwebhook",
            "documents.change_workflowrun",
            "documents.change_workflowtrigger",
            "documents.delete_correspondent",
            "documents.delete_customfield",
            "documents.delete_customfieldinstance",
            "documents.delete_document",
            "documents.delete_documenttype",
            "documents.delete_log",
            "documents.delete_note",
            "documents.delete_paperlesstask",
            "documents.delete_savedview",
            "documents.delete_savedviewfilterrule",
            "documents.delete_sharelink",
            "documents.delete_storagepath",
            "documents.delete_tag",
            "documents.delete_uisettings",
            "documents.delete_workflow",
            "documents.delete_workflowaction",
            "documents.delete_workflowactionemail",
            "documents.delete_workflowactionwebhook",
            "documents.delete_workflowrun",
            "documents.delete_workflowtrigger",
            "documents.view_correspondent",
            "documents.view_customfield",
            "documents.view_customfieldinstance",
            "documents.view_document",
            "documents.view_documenttype",
            "documents.view_log",
            "documents.view_note",
            "documents.view_paperlesstask",
            "documents.view_savedview",
            "documents.view_savedviewfilterrule",
            "documents.view_sharelink",
            "documents.view_storagepath",
            "documents.view_tag",
            "documents.view_uisettings",
            "documents.view_workflow",
            "documents.view_workflowaction",
            "documents.view_workflowactionemail",
            "documents.view_workflowactionwebhook",
            "documents.view_workflowrun",
            "documents.view_workflowtrigger",
            "guardian.add_groupobjectpermission",
            "guardian.add_userobjectpermission",
            "guardian.change_groupobjectpermission",
            "guardian.change_userobjectpermission",
            "guardian.delete_groupobjectpermission",
            "guardian.delete_userobjectpermission",
            "guardian.view_groupobjectpermission",
            "guardian.view_userobjectpermission",
            "mfa.add_authenticator",
            "mfa.change_authenticator",
            "mfa.delete_authenticator",
            "mfa.view_authenticator",
            "paperless.add_applicationconfiguration",
            "paperless.change_applicationconfiguration",
            "paperless.delete_applicationconfiguration",
            "paperless.view_applicationconfiguration",
            "paperless_mail.add_mailaccount",
            "paperless_mail.add_mailrule",
            "paperless_mail.add_processedmail",
            "paperless_mail.change_mailaccount",
            "paperless_mail.change_mailrule",
            "paperless_mail.change_processedmail",
            "paperless_mail.delete_mailaccount",
            "paperless_mail.delete_mailrule",
            "paperless_mail.delete_processedmail",
            "paperless_mail.view_mailaccount",
            "paperless_mail.view_mailrule",
            "paperless_mail.view_processedmail",
            "sessions.add_session",
            "sessions.change_session",
            "sessions.delete_session",
            "sessions.view_session",
            "socialaccount.add_socialaccount",
            "socialaccount.add_socialapp",
            "socialaccount.add_socialtoken",
            "socialaccount.change_socialaccount",
            "socialaccount.change_socialapp",
            "socialaccount.change_socialtoken",
            "socialaccount.delete_socialaccount",
            "socialaccount.delete_socialapp",
            "socialaccount.delete_socialtoken",
            "socialaccount.view_socialaccount",
            "socialaccount.view_socialapp",
            "socialaccount.view_socialtoken",
            "__something_unknown__"
          ],
          "is_active": true,
          "is_mfa_enabled": false,
          "is_staff": true,
          "is_superuser": true,
          "last_name": "",
          "password": "*****************************************************************************************",
          "user_permissions": [],
          "username": "superuser"
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(User.self, from: #require(json.data(using: .utf8)))

        #expect(output.email == "")
        #expect(output.firstName == "")
        #expect(output.groups == [2])
        #expect(output.id == 21)
        #expect(output.inheritedPermissions.count == 176)
        #expect(output.isActive == true)
        #expect(output.isMfaEnabled == false)
        #expect(output.isStaff == true)
        #expect(output.isSuperuser == true)
        #expect(output.lastName == "")
        #expect(output.username == "superuser")
    }

    @Test
    func decode_admin() async throws {
        let json = """
        {
          "date_joined": "2025-10-27T11:20:55.973334+01:00",
          "email": "",
          "first_name": "",
          "groups": [
            2
          ],
          "id": 23,
          "inherited_permissions": [
            "auditlog.add_logentry",
            "auditlog.change_logentry",
            "auditlog.delete_logentry",
            "auditlog.view_logentry",
            "auth.add_group",
            "auth.add_user",
            "auth.change_group",
            "auth.change_user",
            "auth.delete_group",
            "auth.delete_user",
            "auth.view_group",
            "auth.view_user",
            "documents.add_correspondent",
            "documents.add_customfield",
            "documents.add_document",
            "documents.add_documenttype",
            "documents.add_note",
            "documents.add_paperlesstask",
            "documents.add_savedview",
            "documents.add_sharelink",
            "documents.add_storagepath",
            "documents.add_tag",
            "documents.add_uisettings",
            "documents.add_workflow",
            "documents.change_correspondent",
            "documents.change_customfield",
            "documents.change_document",
            "documents.change_documenttype",
            "documents.change_note",
            "documents.change_paperlesstask",
            "documents.change_savedview",
            "documents.change_sharelink",
            "documents.change_storagepath",
            "documents.change_tag",
            "documents.change_uisettings",
            "documents.change_workflow",
            "documents.delete_correspondent",
            "documents.delete_customfield",
            "documents.delete_document",
            "documents.delete_documenttype",
            "documents.delete_note",
            "documents.delete_paperlesstask",
            "documents.delete_savedview",
            "documents.delete_sharelink",
            "documents.delete_storagepath",
            "documents.delete_tag",
            "documents.delete_uisettings",
            "documents.delete_workflow",
            "documents.view_correspondent",
            "documents.view_customfield",
            "documents.view_document",
            "documents.view_documenttype",
            "documents.view_note",
            "documents.view_paperlesstask",
            "documents.view_savedview",
            "documents.view_sharelink",
            "documents.view_storagepath",
            "documents.view_tag",
            "documents.view_uisettings",
            "documents.view_workflow",
            "paperless.add_applicationconfiguration",
            "paperless.change_applicationconfiguration",
            "paperless.delete_applicationconfiguration",
            "paperless.view_applicationconfiguration",
            "paperless_mail.add_mailaccount",
            "paperless_mail.add_mailrule",
            "paperless_mail.change_mailaccount",
            "paperless_mail.change_mailrule",
            "paperless_mail.delete_mailaccount",
            "paperless_mail.delete_mailrule",
            "paperless_mail.view_mailaccount",
            "paperless_mail.view_mailrule",
            "__something_unknown__"
          ],
          "is_active": true,
          "is_mfa_enabled": false,
          "is_staff": true,
          "is_superuser": false,
          "last_name": "",
          "password": "*****************************************************************************************",
          "user_permissions": [],
          "username": "admin"
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(User.self, from: #require(json.data(using: .utf8)))

        #expect(output.email == "")
        #expect(output.firstName == "")
        #expect(output.groups == [2])
        #expect(output.id == 23)
        #expect(output.inheritedPermissions.count == 72)
        #expect(output.isActive == true)
        #expect(output.isMfaEnabled == false)
        #expect(output.isStaff == true)
        #expect(output.isSuperuser == false)
        #expect(output.lastName == "")
        #expect(output.username == "admin")
    }

    @Test
    func decode_user() async throws {
        let json = """
        {
          "date_joined": "2025-10-27T11:32:55.327316+01:00",
          "email": "",
          "first_name": "",
          "groups": [
            3
          ],
          "id": 27,
          "inherited_permissions": [
            "documents.delete_tag",
            "documents.view_tag",
            "documents.change_tag",
            "documents.add_tag",
            "__something_unknown__"
          ],
          "is_active": true,
          "is_mfa_enabled": false,
          "is_staff": false,
          "is_superuser": false,
          "last_name": "",
          "password": "*****************************************************************************************",
          "user_permissions": [
            "add_correspondent",
            "change_correspondent",
            "delete_correspondent",
            "view_correspondent",
            "__something_unknown__"
          ],
          "username": "user"
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(User.self, from: #require(json.data(using: .utf8)))

        #expect(output.email == "")
        #expect(output.firstName == "")
        #expect(output.groups == [3])
        #expect(output.id == 27)
        #expect(output.inheritedPermissions.count == 4)
        #expect(output.isActive == true)
        #expect(output.isMfaEnabled == false)
        #expect(output.isStaff == false)
        #expect(output.isSuperuser == false)
        #expect(output.lastName == "")
        #expect(output.userPermissions.count == 4)
        #expect(output.username == "user")
    }
}
