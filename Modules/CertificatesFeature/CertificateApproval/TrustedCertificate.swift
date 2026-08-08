import Foundation

struct TrustedCertificate: Codable, Equatable, Hashable {

    let issuer: String

    let serialNumber: String
}

extension TrustedCertificate: Identifiable {

    var id: String { serialNumber }
}
