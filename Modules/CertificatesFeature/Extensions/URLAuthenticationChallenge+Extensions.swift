import Dependencies
import Foundation
import X509

extension URLAuthenticationChallenge {
    var firstCertificate: Certificate? {
        @Dependency(\.getFirstCertificate.execute)
        var getFirstCertificate

        return try? getFirstCertificate(self)
    }
}
