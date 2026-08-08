import AsyncAlgorithms
import Dependencies
import DependenciesMacros

extension DependencyValues {

    public var certificateApprovalChannel: AsyncChannel<CertificateApprovalEvent> {
        get { self[CertificateApprovalChannelKey.self] }
        set { self[CertificateApprovalChannelKey.self] = newValue }
    }

    private enum CertificateApprovalChannelKey: DependencyKey {
        static let liveValue = AsyncChannel<CertificateApprovalEvent>()
        static let testValue = AsyncChannel<CertificateApprovalEvent>()
    }
}
