import Components
import Foundation

enum CorrespondentFormField: String, CaseIterable, Hashable {
    case match
    case name
}

extension CorrespondentFormField {

    static var fieldStateKeyPaths: [CorrespondentFormField: WritableKeyPath<CorrespondentFormInput, String?>] {
        [
            .match: \.match.error,
            .name: \.name.error
        ]
    }
}
