import ApiInterface
import Components
import Foundation

public struct StoragePathFormInput: Equatable, Sendable {

    var isInsensitive = true

    var match = FieldState(value: "")

    var matchingAlgorithm: MatchingAlgorithm = .automatic

    var name = FieldState(focused: true, value: "")

    var path = FieldState(focused: false, value: "")

    var owner: Clearable<User.Id>?

    var setPermissions: Permissions?
}

extension StoragePathFormInput {
    init(storagePath: StoragePath?) {
        if let storagePath {
            self.init(
                isInsensitive: storagePath.isInsensitive,
                match: .init(value: storagePath.match),
                matchingAlgorithm: storagePath.matchingAlgorithm,
                name: .init(value: storagePath.name),
                path: .init(value: storagePath.path)
            )
        } else {
            self.init()
        }
    }

    var apiValue: SaveStoragePathInput {
        .init(
            isInsensitive: isInsensitive,
            match: match.value,
            matchingAlgorithm: matchingAlgorithm,
            name: name.value,
            owner: owner,
            path: path.value,
            setPermissions: setPermissions
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in StoragePathFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }
}
