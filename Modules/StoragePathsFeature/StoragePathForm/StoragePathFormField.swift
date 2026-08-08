import Components
import Foundation

enum StoragePathFormField: String, CaseIterable, Hashable {
    case match
    case name
    case path
}

extension StoragePathFormField {

    static var fieldStateKeyPaths: [StoragePathFormField: WritableKeyPath<StoragePathFormInput, String?>] {
        [
            .match: \.match.error,
            .name: \.name.error,
            .path: \.path.error
        ]
    }
}
