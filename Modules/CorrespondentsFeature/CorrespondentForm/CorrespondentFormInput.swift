import ApiInterface
import Components
import Foundation

public struct CorrespondentFormInput: Equatable, Sendable {

    var isInsensitive = true

    var match = FieldState(value: "")

    var matchingAlgorithm: MatchingAlgorithm = .automatic

    var name = FieldState(focused: true, value: "")

    var owner: Clearable<User.Id>?

    var setPermissions: Permissions?
}

extension CorrespondentFormInput {
    init(correspondent: Correspondent?) {
        if let correspondent {
            self.init(
                isInsensitive: correspondent.isInsensitive,
                match: .init(value: correspondent.match),
                matchingAlgorithm: correspondent.matchingAlgorithm,
                name: .init(value: correspondent.name)
            )
        } else {
            self.init()
        }
    }

    var apiValue: SaveCorrespondentInput {
        .init(
            isInsensitive: isInsensitive,
            match: match.value,
            matchingAlgorithm: matchingAlgorithm,
            name: name.value,
            owner: owner,
            setPermissions: setPermissions
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in CorrespondentFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }
}
