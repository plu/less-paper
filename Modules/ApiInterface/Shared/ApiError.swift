import Foundation

public struct ApiError: Decodable, Equatable, Error, LocalizedError, Sendable {

    public let errors: [String]

    public let fieldErrors: [String: [String]]

    public init(
        errors: [String],
        fieldErrors: [String: [String]] = [:]
    ) {
        self.errors = errors
        self.fieldErrors = fieldErrors
    }
}

public extension ApiError {

    var errorDescription: String? {
        errors.joined(separator: "\n")
    }

    func errorForField(_ field: String) -> String? {
        guard let fieldErrorMessages = fieldErrors[field], !fieldErrorMessages.isEmpty else {
            return nil
        }
        return fieldErrorMessages.joined(separator: "\n")
    }
}

extension ApiError {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        for key: CodingKeys in [.error, .errors] {
            do {
                errors = try container.decode([String].self, forKey: key)
                fieldErrors = [:]
                return
            } catch {}
            do {
                errors = try [container.decode(String.self, forKey: key)]
                fieldErrors = [:]
                return
            } catch {}
        }

        do {
            errors = try [container.decode(String.self, forKey: .detail)]
            fieldErrors = [:]
            return
        } catch {}

        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var allErrors: [String] = []
        var fieldErrorsDict: [String: [String]] = [:]

        for key in dynamicContainer.allKeys {
            do {
                let fieldErrorMessages = try dynamicContainer.decode([String].self, forKey: key)
                fieldErrorsDict[key.stringValue] = fieldErrorMessages
                allErrors.append(contentsOf: fieldErrorMessages)
            } catch {
                do {
                    let fieldError = try dynamicContainer.decode(String.self, forKey: key)
                    fieldErrorsDict[key.stringValue] = [fieldError]
                    allErrors.append(fieldError)
                } catch {
                    continue
                }
            }
        }

        if !allErrors.isEmpty {
            errors = allErrors
            fieldErrors = fieldErrorsDict
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "No valid error format found in response. Expected 'error', 'errors', 'detail', or field validation errors."
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case error, detail
        case errors = "non_field_errors"
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}

public extension ApiError {

    static func testValue(
        errors: [String] = ["Something went wrong"],
        fieldErrors: [String: [String]] = [:]
    ) -> Self {
        .init(
            errors: errors,
            fieldErrors: fieldErrors
        )
    }
}

public extension Error {

    var isMfaCodeRequiredError: Bool {
        guard let apiError = self as? ApiError else {
            return false
        }
        return apiError.errors.contains("MFA code is required")
    }
}
