import ApiInterface
import Foundation
import SwiftSharing

extension DocumentFormReducer.State {

    static func testValue(
        content: String? = nil,
        destination: DocumentFormReducer.Destination.State? = nil,
        document: Document = .testValue(),
        loadError: String? = nil,
        section: DocumentFormSection = .details,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            destination: destination,
            document: Shared(value: document),
            server: server
        )
        state.content = content
        state.loadError = loadError
        state.section = section
        return state
    }
}
