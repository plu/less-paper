import Components
import DesignTokens
import SwiftUI

struct CertificateApprovalView: View {
    var body: some View {
        Sheet {
            Text(.certificateApprovalTitle)
        } content: {
            VStack(alignment: .leading, spacing: .x4) {
                Text(.certificateApprovalMessage).font(.body)
                section(title: .url, value: url)
                section(title: .certificateSerialNumber, value: serialNumber)
                section(title: .certificateIssuer, value: issuer)
            }
            .foregroundStyle(Color.m3OnSurface)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        } bottom: {
            AdaptiveStack {
                Button {
                    cancel()
                } label: {
                    Text(.cancel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
                .frame(maxWidth: .infinity)

                Button {
                    approve()
                } label: {
                    Text(.certificateApprovalAccept)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.critical())
            }
        }
        .background(Color.m3Surface)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .padding(.x4)
        .frame(maxWidth: 600)
    }

    init(
        issuer: String,
        serialNumber: String,
        url: String?,
        approve: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        self.issuer = issuer
        self.serialNumber = serialNumber
        self.url = url
        self.approve = approve
        self.cancel = cancel
    }

    @ViewBuilder
    func section(title: LocalizedStringResource, value: String?) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: .x1) {
                Text(title)
                    .foregroundStyle(Color.m3Outline)
                Text(value)
            }
            .font(.footnote)
            .monospaced()
        }
    }

    private let issuer: String
    private let serialNumber: String
    private let url: String?
    private let approve: () -> Void
    private let cancel: () -> Void
}

extension CertificateApprovalView {
    static func testValue(
        issuer: String = "CN=Caddy Local Authority - ECC Intermediate",
        serialNumber: String = "a0:e8:e1:3:50:9a:53:fc:2d:52:df:d5:6e:2e:48:43",
        url: String? = "https://localhost:8010",
        approve: @escaping () -> Void = {},
        cancel: @escaping () -> Void = {}
    ) -> Self {
        .init(
            issuer: issuer,
            serialNumber: serialNumber,
            url: url,
            approve: approve,
            cancel: cancel
        )
    }
}
