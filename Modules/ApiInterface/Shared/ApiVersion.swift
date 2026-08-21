import Foundation

public enum ApiVersion {

    public static let clientMaximum = 10

    public static let minimumSupported = 9

    public static func negotiated(from advertised: Int?) throws -> Int {
        guard let advertised, advertised >= minimumSupported else {
            throw ApiVersionError.unsupportedServer(advertised)
        }
        return min(advertised, clientMaximum)
    }
}
