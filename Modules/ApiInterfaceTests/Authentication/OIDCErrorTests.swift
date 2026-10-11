import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct OIDCErrorTests {

    @Test
    func errorDescription_namesTheProviderAndTheAdmin() {
        let error = OIDCError.accountNotLinked(provider: "Pocket ID")

        #expect(error.errorDescription?.contains("Pocket ID") == true)
        #expect(error.errorDescription?.contains("administrator") == true)
    }

    @Test
    func errorDescription_namesTheProviderAndTheFix() {
        let error = OIDCError.confidentialClient(provider: "Pocket ID")

        #expect(error.errorDescription?.contains("Pocket ID") == true)
        #expect(error.errorDescription?.contains("public") == true)
    }

    @Test
    func errorDescription_isAbsentForOtherFailures() {
        #expect(OIDCError.tokenExchangeFailed(reason: "status 500").errorDescription == nil)
    }
}
