import ApiInterface
import Foundation
import Testing

@Suite
struct ForwardAuthErrorTests {

    @Test
    func errorDescription_namesTheHost() {
        let error = ForwardAuthError.required(URL(string: "https://auth.example.com/login")!)

        #expect(error.errorDescription?.contains("auth.example.com") == true)
    }
}
