@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct ApiErrorTests {

    @Test
    func decodeSingleError() async throws {
        let json = """
        {
          "error": "Something went wrong"
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["Something went wrong"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func decodeMultipleErrorsFromErrorField() async throws {
        let json = """
        {
          "error": ["Error 1", "Error 2", "Error 3"]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["Error 1", "Error 2", "Error 3"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func decodeSingleErrorFromNonFieldErrors() async throws {
        let json = """
        {
          "non_field_errors": ["General validation error"]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["General validation error"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func decodeSingleErrorFromDetail() async throws {
        let json = """
        {
          "detail": "Authentication credentials were not provided"
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["Authentication credentials were not provided"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func decodeSingleFieldValidationError() async throws {
        let json = """
        {
          "name": ["This field may not be blank."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["This field may not be blank."])
        expectNoDifference(apiError.fieldErrors, ["name": ["This field may not be blank."]])
        expectNoDifference(apiError.errorForField("name"), "This field may not be blank.")
    }

    @Test
    func decodeMultipleFieldValidationErrorsFromOneField() async throws {
        let json = """
        {
          "password": [
            "This password is too short. It must contain at least 8 characters.",
            "This password is too common."
          ]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, [
            "This password is too short. It must contain at least 8 characters.",
            "This password is too common."
        ])
        expectNoDifference(apiError.fieldErrors, [
            "password": [
                "This password is too short. It must contain at least 8 characters.",
                "This password is too common."
            ]
        ])
        expectNoDifference(
            apiError.errorForField("password"),
            "This password is too short. It must contain at least 8 characters.\nThis password is too common."
        )
    }

    @Test
    func decodeValidationErrorsFromMultipleFields() async throws {
        let json = """
        {
          "email": ["Enter a valid email address."],
          "password": ["This field may not be blank."],
          "username": ["A user with that username already exists."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        let expectedErrors = [
            "Enter a valid email address.",
            "This field may not be blank.",
            "A user with that username already exists."
        ]

        expectNoDifference(Set(apiError.errors), Set(expectedErrors))
        expectNoDifference(apiError.errorForField("email"), "Enter a valid email address.")
        expectNoDifference(apiError.errorForField("password"), "This field may not be blank.")
        expectNoDifference(apiError.errorForField("username"), "A user with that username already exists.")
    }

    @Test
    func decodeMixedFieldErrors() async throws {
        let json = """
        {
          "name": "This field is required.",
          "tags": ["Invalid tag format.", "Tag name too long."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        let expectedErrors = [
            "This field is required.",
            "Invalid tag format.",
            "Tag name too long."
        ]

        expectNoDifference(Set(apiError.errors), Set(expectedErrors))
        expectNoDifference(apiError.errorForField("name"), "This field is required.")
        expectNoDifference(apiError.errorForField("tags"), "Invalid tag format.\nTag name too long.")
    }

    @Test
    func legacyErrorTakesPrecedence() async throws {
        let json = """
        {
          "error": "Server error occurred",
          "name": ["This field may not be blank."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["Server error occurred"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func nonFieldErrorsTakesPrecedence() async throws {
        let json = """
        {
          "non_field_errors": ["Authentication failed"],
          "username": ["This field is required."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errors, ["Authentication failed"])
        expectNoDifference(apiError.fieldErrors, [:])
    }

    @Test
    func throwErrorWhenNoValidFormat() async throws {
        let json = """
        {
          "status": 400,
          "timestamp": 1234567890
        }
        """

        #expect(throws: DecodingError.self) {
            try ApiErrorTests.testValueFromJSON(json)
        }
    }

    @Test
    func provideLocalizedErrorDescription() async throws {
        let json = """
        {
          "email": ["Enter a valid email address."],
          "password": ["This field may not be blank."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)
        let description = apiError.errorDescription

        #expect(description?.contains("Enter a valid email address.") == true)
        #expect(description?.contains("This field may not be blank.") == true)
        #expect(description?.contains("\n") == true)
    }

    @Test
    func provideLocalizedErrorDescriptionForSingleError() async throws {
        let json = """
        {
          "error": "Authentication failed"
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        expectNoDifference(apiError.errorDescription, "Authentication failed")
    }

    @Test
    func returnNilForNonExistentField() async throws {
        let json = """
        {
          "name": ["This field may not be blank."]
        }
        """

        let apiError = try ApiErrorTests.testValueFromJSON(json)

        #expect(apiError.errorForField("email") == nil)
        #expect(apiError.errorForField("nonexistent") == nil)
    }
}

extension ApiErrorTests {

    static func testValueFromJSON(_ jsonString: String) throws -> ApiError {
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try decoder.decode(ApiError.self, from: data)
    }
}
