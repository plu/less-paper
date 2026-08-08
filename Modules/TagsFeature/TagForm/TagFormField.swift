import Components
import Foundation

enum TagFormField: String, CaseIterable, Hashable {
    case match
    case name
}

extension TagFormField {

    static var fieldStateKeyPaths: [TagFormField: WritableKeyPath<TagFormInput, String?>] {
        [
            .match: \.match.error,
            .name: \.name.error
        ]
    }
}
