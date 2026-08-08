import Foundation

@propertyWrapper
public struct SkipUnknownValues<T: Codable> {

    public var wrappedValue: [T]

    public init(wrappedValue: [T]) {
        self.wrappedValue = wrappedValue
    }
}

extension SkipUnknownValues: Decodable {

    public init(from decoder: Decoder) throws {
        wrappedValue = try decoder
            .singleValueContainer()
            .decode([MaybeDecodable<T>].self)
            .compactMap(\.wrapped)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension SkipUnknownValues: Encodable where T: Encodable {}

extension SkipUnknownValues: Equatable where T: Equatable {}

extension SkipUnknownValues: Hashable where T: Hashable {}

extension SkipUnknownValues: Sendable where T: Sendable {}
