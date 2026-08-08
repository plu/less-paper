import Foundation

public extension JSONDecoder {

    static let apiDecoder = {
        let decoder = JSONDecoder()
        let dateFormatters = [
            DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"),
            DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ssZ"),
            DateFormatter(dateFormat: "yyyy-MM-dd"),
        ]
        decoder.dateDecodingStrategy = .custom { decoder in
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
