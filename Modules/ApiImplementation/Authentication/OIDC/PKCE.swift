import CryptoKit
import Foundation

/// Proof Key for Code Exchange, RFC 7636.
///
/// The app cannot keep a client secret - anything shipped in a binary can be read out of it - so it
/// authenticates the code exchange by proving it is the same client that started the flow. It sends
/// the hash up front and the original value at the end; an attacker who intercepts the
/// authorization code has neither.
struct PKCE: Equatable, Sendable {

    /// Sent with the authorization request.
    let challenge: String

    /// Sent with the code exchange, and never before.
    let verifier: String

    init(verifier: String = PKCE.randomVerifier()) {
        self.verifier = verifier
        challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    /// 32 bytes, which base64url-encodes to 43 characters - the shortest the RFC permits, and long
    /// enough that guessing it is not a strategy.
    static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        // A verifier from a weak source is worse than none, because the flow would still appear to
        // work while proving nothing.
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with \(status)")
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {

    /// base64url, per RFC 4648 §5: the URL-safe alphabet, and no padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
