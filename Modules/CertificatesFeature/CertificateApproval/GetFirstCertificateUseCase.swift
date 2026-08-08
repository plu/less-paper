import Dependencies
import DependenciesMacros
import Foundation
import X509

@DependencyClient
struct GetFirstCertificateUseCase: Sendable {

    var execute: @Sendable (
        _ authenticationChallenge: URLAuthenticationChallenge
    ) throws -> Certificate?
}

extension DependencyValues {
    var getFirstCertificate: GetFirstCertificateUseCase {
        get { self[GetFirstCertificateUseCase.self] }
        set { self[GetFirstCertificateUseCase.self] = newValue }
    }
}

extension GetFirstCertificateUseCase: DependencyKey, TestDependencyKey {
    static let liveValue = GetFirstCertificateUseCase(
        execute: execute(authenticationChallenge:)
    )

    static let testValue = GetFirstCertificateUseCase(
        execute: { _ in try .testValue() }
    )
}

extension GetFirstCertificateUseCase {

    static func execute(
        authenticationChallenge: URLAuthenticationChallenge
    ) throws -> Certificate? {
        guard authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            return nil
        }

        guard let serverTrust = authenticationChallenge.protectionSpace.serverTrust else {
            return nil
        }

        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate], let certificate = certificates.first else {
            return nil
        }

        return try Certificate(certificate)
    }
}
