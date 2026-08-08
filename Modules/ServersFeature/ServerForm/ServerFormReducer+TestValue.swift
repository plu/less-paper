import ApiInterface
import Foundation

extension ServerFormReducer.State {

    static func testValue(
        input: ServerFormInput = .testValue()
    ) -> Self {
        .init(
            input: input
        )
    }
}
