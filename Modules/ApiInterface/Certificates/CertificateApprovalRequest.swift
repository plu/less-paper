import Dependencies
import Foundation

public struct CertificateApprovalRequest: Equatable, Identifiable, Sendable, CustomDebugStringConvertible {

    public let challenge: URLAuthenticationChallenge

    public let completion: @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

    public let id: UUID

    public let url: URL?

    public init(
        challenge: URLAuthenticationChallenge,
        completion: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
        id: UUID = Dependency(\.uuid).wrappedValue(),
        url: URL?
    ) {
        self.challenge = challenge
        self.completion = completion
        self.id = id
        self.url = url
    }
}

public extension CertificateApprovalRequest {
    var debugDescription: String {
        "<CertificateApprovalRequest: id=\(id) url=\(url?.absoluteString ?? "<unknown>")>"
    }

    static func == (lhs: CertificateApprovalRequest, rhs: CertificateApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }
}

public extension CertificateApprovalRequest {
    static func testValue(
        challenge: URLAuthenticationChallenge = .testValue(),
        completion: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { _, _ in },
        id: UUID = Dependency(\.uuid).wrappedValue(),
        url: URL? = .testValue()
    ) -> Self {
        .init(
            challenge: challenge,
            completion: completion,
            id: id,
            url: url
        )
    }
}

public extension URLAuthenticationChallenge {
    static func testValue() -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: TestURLProtectionSpace(),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeURLAuthenticationChallengeSender()
        )
    }
}

public final class TestURLProtectionSpace: URLProtectionSpace, @unchecked Sendable {
    override public init() {
        super.init(
            host: "localhost",
            port: 8010,
            protocol: "https",
            realm: nil,
            authenticationMethod: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var serverTrust: SecTrust? {
        let certificate = "MIIDCzCCAfOgAwIBAgIUBn/yoPUWc4a/oYkM2UXsPICg5BwwDQYJKoZIhvcNAQELBQAwFTETMBEGA1UEAwwKdGVzdC5sb2NhbDAeFw0yNjAxMzEwOTQ1MTNaFw0zNjAxMjkwOTQ1MTNaMBUxEzARBgNVBAMMCnRlc3QubG9jYWwwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC/kwbXV/zUFwJ5mprUwWjY5E6lfWcDhjeQhAGRWCYIoCV51E5ftX0L6BlmJIR7K/7UgPoVL69kcX/Re5QiygWDwA7k+xUNqz5BWCEp0/hEftbN5uPwmbU3lZOY663YT0cwtJE76WoCu93K051KVjpzRsls0HHroWyxDoPoPN/KOhoPSbTFg7DI36qgj9ergs4apXdBtMkAr1mITqNPj07vFAzmGBxSTm5+FilRLDTX9QR0okujO+76W+0BppXiybPUXKpgBcUU/rC9NsmSC65KulAyRkWtPFQ1USgCrRaO6fNDMGI9N7dszx418an2zYHfm7Kpy2I0q2ShOVslT4UJAgMBAAGjUzBRMB0GA1UdDgQWBBQ8NAHQNt30q/x7aQFiLy08JHrpajAfBgNVHSMEGDAWgBQ8NAHQNt30q/x7aQFiLy08JHrpajAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQBQmnAD38As3yFq+3cu3GfNyWJDHHPON5IVtEP9H+7sZQ9vSu6GRyduaupJO2uBYXhEFP70HVWlzyHRYqoeUhxdCVaWUZ4EGNox7ExEiIw1wQZ+YhWNkW2SA0cPLeL5LcwBZtqweEfODbfNMdbZj4xasOEhY27PQW4fKBZhGCN+29/K7uGvDK4assqKsJnO2UZOHpcuqofgi0PVsrNpEdmEu3AXbZx9vEzi+Z3i9uAlsDtL6D2bplzwm3EVmUVgcJWeqgmLg57c663RQIW7NpkZkeA0Y6zGnmNO5itYeMm/h6VgmuWStPtA4QOp621MR7gY+HSIbBv9DqF2O0Or0CSe"
        guard let data = Data(base64Encoded: certificate),
              let cert = SecCertificateCreateWithData(nil, data as CFData)
        else {
            return nil
        }
        let policy = SecPolicyCreateSSL(true, "test.local" as CFString)
        var trust: SecTrust?
        SecTrustCreateWithCertificates(cert, policy, &trust)
        return trust
    }
}

private final class FakeURLAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
