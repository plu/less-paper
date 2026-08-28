@testable import ApiImplementation

import CryptoKit
import Foundation
import Testing

@Suite
struct PKCETests {

    // The worked example from RFC 7636 appendix B, which is the only way to know the encoding is
    // right rather than merely self-consistent: a wrong-but-consistent implementation would pass a
    // round-trip test and be rejected by every real provider.
    @Test
    func test_challenge_matchesTheWorkedExampleFromTheRFC() {
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test
    func test_challenge_isBase64URLWithoutPadding() {
        let challenge = PKCE().challenge

        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        #expect(!challenge.contains("="))
    }

    // 43 is the shortest the RFC permits.
    @Test
    func test_verifier_isLongEnough() {
        #expect(PKCE().verifier.count >= 43)
    }

    @Test
    func test_verifier_differsEveryTime() {
        let verifiers = Set((0 ..< 50).map { _ in PKCE().verifier })

        #expect(verifiers.count == 50)
    }
}
