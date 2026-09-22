import Foundation

public enum ApiVersion {

    public static let clientMaximum = 10

    // paperless-ngx 2.15.3 is the first release whose ALLOWED_VERSIONS reaches 8 - 2.15.2 and
    // earlier top out at 7 - so this constant is what the README and the App Store listing mean
    // when they say the app needs 2.15.3 or newer. Raising it moves that floor.
    public static let minimumSupported = 8

    // paperless-ngx 3.0.0 both introduced the Tantivy-backed `text` / `title_search` parameters and
    // bumped the API version to 10, so no release has one without the other. The gate matters
    // because an older server does not reject `text`, it ignores it and answers with every
    // document.
    public static let tantivyTextSearch = 10

    public static func negotiated(from advertised: Int?) throws -> Int {
        guard let advertised, advertised >= minimumSupported else {
            throw ApiVersionError.unsupportedServer(advertised)
        }
        return min(advertised, clientMaximum)
    }
}
