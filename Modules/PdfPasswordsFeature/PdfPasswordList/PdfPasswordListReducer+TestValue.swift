import ApiInterface
import Foundation
import IdentifiedCollections

extension PdfPasswordListReducer.State {

    static func testValue(
        isLoaded: Bool = true,
        pdfPasswords: [PdfPassword] = []
    ) -> Self {
        .init(
            isLoaded: isLoaded,
            pdfPasswords: IdentifiedArray(
                uniqueElements: pdfPasswords.map {
                    PdfPasswordRowReducer.State(pdfPassword: $0)
                }
            )
        )
    }
}
