import Foundation

public extension JSONEncoder {

    static let apiEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(.createdDate)
        encoder.keyEncodingStrategy = .convertToSnakeCase
        #if DEBUG
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        #endif
        return encoder
    }()
}
