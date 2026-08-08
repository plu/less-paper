import ApiInterface
import Foundation

extension MfaFormReducer.State {

    static func testValue(
        mfaCode: String = ""
    ) -> Self {
        .init(
            mfaCode: mfaCode
        )
    }
}
