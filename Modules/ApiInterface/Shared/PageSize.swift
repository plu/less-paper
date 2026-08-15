import Foundation

public enum PageSize {
    public static let `default` = 100

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
