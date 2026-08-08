import ApiInterface
import Foundation

extension ShareFormReducer.State {
    static func testValue(
        files: [URL] = [.testPDF(named: "Puky.pdf")],
        server: Server = .testValue()
    ) -> Self {
        .init(
            files: files,
            server: server
        )
    }
}
