import Foundation

public enum CertificateApprovalEvent: Equatable, Sendable {
    case request(CertificateApprovalRequest)
    case response(CertificateApprovalRequest, Bool)
}
