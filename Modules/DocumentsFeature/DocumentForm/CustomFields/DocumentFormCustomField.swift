import ApiInterface
import Foundation

// The field id, not the CustomField: the definition is read from the cache at render time, so a
// rename on the server cannot register as an unsaved edit on an open sheet.
struct DocumentFormCustomField: Equatable, Identifiable, Sendable {

    let id: CustomField.Id

    var value: DocumentFormCustomFieldValue
}
