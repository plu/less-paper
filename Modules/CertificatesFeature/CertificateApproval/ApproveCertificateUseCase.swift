import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct ApproveCertificateUseCase: Sendable {
    var execute: @Sendable (
        _ request: CertificateApprovalRequest
    ) -> Bool = { _ in false }
}

extension DependencyValues {
    var approveCertificate: ApproveCertificateUseCase {
        get { self[ApproveCertificateUseCase.self] }
        set { self[ApproveCertificateUseCase.self] = newValue }
    }
}

extension ApproveCertificateUseCase: DependencyKey, TestDependencyKey {
    static let liveValue = ApproveCertificateUseCase(
        execute: execute(request:)
    )

    static let testValue = ApproveCertificateUseCase()
}

extension ApproveCertificateUseCase {
    @discardableResult
    static func execute(
        request: CertificateApprovalRequest
    ) -> Bool {
        guard let serverTrust = request.challenge.protectionSpace.serverTrust else {
            return false
        }
        request.completion(.useCredential, URLCredential(trust: serverTrust))
        return true
    }
}
