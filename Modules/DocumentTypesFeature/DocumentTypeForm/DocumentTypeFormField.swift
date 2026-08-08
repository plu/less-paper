import Components
import Foundation

enum DocumentTypeFormField: String, CaseIterable, Hashable {
    case match
    case name
}

extension DocumentTypeFormField {

    static var fieldStateKeyPaths: [DocumentTypeFormField: WritableKeyPath<DocumentTypeFormInput, String?>] {
        [
            .match: \.match.error,
            .name: \.name.error
        ]
    }
}
