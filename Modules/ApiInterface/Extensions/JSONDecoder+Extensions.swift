import Foundation

public extension JSONDecoder {

    static let apiDecoder = {
        let decoder = JSONDecoder()
        decoder.configureForApi()
        return decoder
    }()

    /// Applied rather than baked into `apiDecoder`, so a subclass - `LoggingJSONDecoder` - can carry
    /// exactly the same behaviour instead of a copy of it that quietly drifts.
    func configureForApi() {
        let dateFormatters = [
            DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"),
            DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ssZ"),
            DateFormatter(dateFormat: "yyyy-MM-dd"),
        ]
        dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            for dateFormatter in dateFormatters {
                if let date = dateFormatter.date(from: value) {
                    return date
                }
            }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported date format"
                )
            )
        }
        keyDecodingStrategy = .convertFromSnakeCase
    }
}
