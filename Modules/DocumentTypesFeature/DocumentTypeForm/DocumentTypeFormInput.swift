import ApiInterface
import Components
import Foundation

public struct DocumentTypeFormInput: Equatable, Sendable {

    var isInsensitive = true

    var match = FieldState(value: "")

    var matchingAlgorithm: MatchingAlgorithm = .automatic

    var name = FieldState(focused: true, value: "")

    var owner: Clearable<User.Id>?

    var setPermissions: Permissions?
}

extension DocumentTypeFormInput {
    init(documentType: DocumentType?) {
        if let documentType {
            self.init(
                isInsensitive: documentType.isInsensitive,
                match: .init(value: documentType.match),
                matchingAlgorithm: documentType.matchingAlgorithm,
                name: .init(value: documentType.name)
            )
        } else {
            self.init()
        }
    }

    var apiValue: SaveDocumentTypeInput {
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
        for (fieldName, keyPath) in DocumentTypeFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }
}
