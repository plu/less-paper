import Components
import Foundation

enum CustomFieldFormField: String, CaseIterable, Hashable {
    case name
}

extension CustomFieldFormField {

    static var fieldStateKeyPaths: [CustomFieldFormField: WritableKeyPath<CustomFieldFormInput, String?>] {
        [
            .name: \.name.error
        ]
    }
}
