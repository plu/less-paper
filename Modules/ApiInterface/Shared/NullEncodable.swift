import Foundation

@propertyWrapper
public struct NullEncodable<T>: Encodable & Equatable & Sendable where T: Encodable & Equatable & Sendable {

    public var wrappedValue: T?

    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch wrappedValue {
        case let .some(value):
            try container.encode(value)
        case .none:
            try container.encodeNil()
        }
    }
}
