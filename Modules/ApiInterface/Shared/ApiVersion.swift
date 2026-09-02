import Foundation

public enum ApiVersion {

    public static let clientMaximum = 10

    // paperless-ngx 2.15.3 is the first release whose ALLOWED_VERSIONS reaches 8 - 2.15.2 and
    // earlier top out at 7 - so this constant is what the README and the App Store listing mean
    // when they say the app needs 2.15.3 or newer. Raising it moves that floor.
    public static let minimumSupported = 8

    public static func negotiated(from advertised: Int?) throws -> Int {
        guard let advertised, advertised >= minimumSupported else {
            throw ApiVersionError.unsupportedServer(advertised)
        }
        return min(advertised, clientMaximum)
    }
}
