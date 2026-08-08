import ApiInterface
import Components
import Foundation

public struct TagFormInput: Equatable, Sendable {

    var color = "#006A68"

    var isInboxTag = false

    var isInsensitive = true

    var match = FieldState(value: "")

    var matchingAlgorithm: MatchingAlgorithm = .automatic

    var name = FieldState(focused: true, value: "")

    var owner: Clearable<User.Id>?

    var setPermissions: Permissions?
}

extension TagFormInput {
    init(tag: Tag?) {
        if let tag {
            self.init(
                color: tag.color,
                isInboxTag: tag.isInboxTag,
                isInsensitive: tag.isInsensitive,
                match: .init(value: tag.match),
                matchingAlgorithm: tag.matchingAlgorithm,
                name: .init(value: tag.name)
            )
        } else {
            self.init()
        }
    }

    var apiValue: SaveTagInput {
        .init(
            color: color,
            isInboxTag: isInboxTag,
            isInsensitive: isInsensitive,
            match: match.value,
            matchingAlgorithm: matchingAlgorithm,
            name: name.value,
            owner: owner,
            setPermissions: setPermissions
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in TagFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }
}
