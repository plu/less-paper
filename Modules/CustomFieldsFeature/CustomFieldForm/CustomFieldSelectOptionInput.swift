import ApiInterface
import Components
import Foundation

struct CustomFieldSelectOptionInput: Equatable, Identifiable, Sendable {

    // `id` is client-side and exists only so SwiftUI can identify a row the user has just added:
    // the server assigns `serverId` on save, so a brand new option has nothing else to be keyed by.
    let id: UUID

    var label: String

    let serverId: String?
}

extension CustomFieldSelectOptionInput {

    var apiValue: CustomFieldSelectOption {
        .init(
            id: serverId,
            label: label
        )
    }
}
