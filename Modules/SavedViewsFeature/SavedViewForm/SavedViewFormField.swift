import Components
import Foundation

enum SavedViewFormField: String, CaseIterable, Hashable {
    case name
}

extension SavedViewFormField {

    static var fieldStateKeyPaths: [SavedViewFormField: WritableKeyPath<SavedViewFormInput, String?>] {
        [
            .name: \.name.error
        ]
    }
}
