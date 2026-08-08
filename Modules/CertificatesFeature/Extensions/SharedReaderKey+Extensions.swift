import Foundation
import IdentifiedCollections
import SwiftSharing

extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<TrustedCertificate>>.Default {

    static var trustedCertificates: Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "trusted-certificates.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

private extension URL {

    static var applicationGroupDirectory: URL {
        guard let applicationGroupDirectory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.plunien.app.Paperless")
        else {
            return .documentsDirectory
        }
        return applicationGroupDirectory
    }
}
