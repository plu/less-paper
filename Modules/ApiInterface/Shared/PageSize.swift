import Foundation

/// The number of documents requested per page when listing documents
public enum PageSize {

    /// The page size used unless `PAPERLESS_PAGE_SIZE` overrides it
    public static let `default` = 100

    /// The configured page size, read from the `PAPERLESS_PAGE_SIZE` Info.plist key
    public static var configured: Int {
        value(from: #bundle.infoDictionary?["PAPERLESS_PAGE_SIZE"] as? String)
    }

    static func value(from string: String?) -> Int {
        guard let string,
              let value = Int(string),
              value > 0
        else {
            return `default`
        }
        return value
    }
}
