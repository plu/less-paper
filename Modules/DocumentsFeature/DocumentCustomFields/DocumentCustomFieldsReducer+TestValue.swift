import ApiInterface
import ComposableArchitecture

extension DocumentCustomFieldsReducer.State {

    static func testValue(
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            document: Shared(value: document),
            server: server
        )
    }
}
