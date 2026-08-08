import Foundation

public enum Clearable<T: Encodable>: Encodable {
    case clear
    case value(T)

    public init(value: T?) {
        if let value {
            self = .value(value)
        } else {
            self = .clear
        }
    }

    public func map<U: Encodable>(_ transform: (T) -> U) -> Clearable<U> {
        switch self {
        case .clear:
            return .clear
        case let .value(wrappedValue):
            return .value(transform(wrappedValue))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .value(value):
            try container.encode(value)
        case .clear:
            try container.encodeNil()
        }
    }
}

extension Clearable: Decodable where T: Decodable {}

extension Clearable: Equatable where T: Equatable {}

extension Clearable: Hashable where T: Hashable {}

extension Clearable: Sendable where T: Sendable {}
